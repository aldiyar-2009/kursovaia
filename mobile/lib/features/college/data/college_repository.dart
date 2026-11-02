import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/features/college/data/college_models.dart';

/// SharedPreferences keys of the college data; removed on logout.
const kCollegeSnapshotPrefsKey = 'college.snapshot';
const kCollegeTimetableIdsPrefsKey = 'college.timetable_ids';
const kCollegeGroupPrefsKey = 'college.group';

/// Subject colours for the imported timetable (same set as the lesson editor
/// would offer; chosen by a hash of the subject name).
const _subjectColors = [
  '#2563EB',
  '#0F766E',
  '#D97706',
  '#7C3AED',
  '#DB2777',
  '#059669',
  '#DC2626',
  '#0891B2',
  '#65A30D',
];

/// Snapshot loaded from the cache or the server.
class SnapshotResult {
  final SnSnapshot? snapshot;

  /// True when the server could not be reached and the cache is shown.
  final bool fromCache;

  const SnapshotResult(this.snapshot, {this.fromCache = false});
}

/// College data: SmartNation snapshot (grades, assignments) and the group
/// timetable, which is imported into the ordinary `subjects` / `lessons`
/// tables so Home, reminders, ICS export and sync work with it as usual.
class CollegeRepository {
  final ApiClient apiClient;
  final AppDatabase db;

  CollegeRepository({required this.apiClient, required this.db});

  Future<SnSnapshot?> cachedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kCollegeSnapshotPrefsKey);
    if (raw == null) return null;
    try {
      return SnSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Latest snapshot from the server ([refresh] asks it to re-read
  /// SmartNation); falls back to the cache when offline.
  Future<SnapshotResult> loadSnapshot({bool refresh = false}) async {
    try {
      final res = refresh
          ? await apiClient.dio.post<Map<String, dynamic>>('/college/refresh')
          : await apiClient.dio.get<Map<String, dynamic>>('/college/snapshot');
      final json = res.data?['snapshot'];
      if (json is! Map<String, dynamic>) {
        return SnapshotResult(await cachedSnapshot(), fromCache: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kCollegeSnapshotPrefsKey, jsonEncode(json));
      return SnapshotResult(SnSnapshot.fromJson(json));
    } catch (_) {
      return SnapshotResult(await cachedSnapshot(), fromCache: true);
    }
  }

  /// Group names that have a timetable on the server.
  Future<List<String>> timetableGroups() async {
    final res = await apiClient.dio.get<Map<String, dynamic>>(
      '/timetable/groups',
    );
    return [for (final g in (res.data?['groups'] as List?) ?? const []) '$g'];
  }

  Future<List<CollegeLesson>> fetchTimetable(String group) async {
    final res = await apiClient.dio.get<Map<String, dynamic>>(
      '/timetable',
      queryParameters: {'group': group},
    );
    return [
      for (final l in (res.data?['lessons'] as List?) ?? const [])
        CollegeLesson.fromJson(l as Map<String, dynamic>),
    ];
  }

  /// Group whose timetable was imported last (to offer «refresh»).
  static Future<String?> savedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kCollegeGroupPrefsKey);
  }

  /// Downloads the timetable of [group] and writes it into the user's
  /// subjects and lessons. Ids are stable, so a repeated import updates the
  /// same rows; pairs that disappeared from the timetable are deleted.
  /// Returns the number of pairs.
  Future<int> importTimetable(String userId, String group) async {
    final lessons = await fetchTimetable(group);
    await applyTimetable(db, userId, group, lessons);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCollegeGroupPrefsKey, group);
    return lessons.length;
  }
}

/// Writes [lessons] of [group] into drift (see
/// [CollegeRepository.importTimetable]); separate for tests.
Future<void> applyTimetable(
  AppDatabase db,
  String userId,
  String group,
  List<CollegeLesson> lessons,
) async {
  final prefs = await SharedPreferences.getInstance();
  final previous =
      prefs.getStringList(kCollegeTimetableIdsPrefsKey) ?? const [];
  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  final keep = <String>{};

  await db.transaction(() async {
    final subjects = await (db.select(
      db.subjects,
    )..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))).get();
    final byTitle = {for (final s in subjects) s.title.toLowerCase(): s};
    final subjectIds = <String, String>{};

    for (final l in lessons) {
      final title = _clip(l.subject.trim(), 160);
      if (title.isEmpty || subjectIds.containsKey(title)) continue;
      final existing = byTitle[title.toLowerCase()];
      if (existing != null) {
        subjectIds[title] = existing.id;
        final teacher = l.teacher?.trim();
        if ((existing.teacherName ?? '').isEmpty &&
            teacher != null &&
            teacher.isNotEmpty) {
          await (db.update(
            db.subjects,
          )..where((t) => t.id.equals(existing.id))).write(
            SubjectsCompanion(
              teacherName: Value(_clip(teacher, 160)),
              updatedAt: Value(now),
              syncStatus: Value(_pending(existing.syncStatus)),
            ),
          );
        }
        continue;
      }
      final id = UuidUtil.stable(userId, 'college-subject:$title');
      subjectIds[title] = id;
      await db
          .into(db.subjects)
          .insertOnConflictUpdate(
            SubjectsCompanion.insert(
              id: id,
              userId: userId,
              title: title,
              teacherName: Value(_nullIfEmpty(l.teacher, 160)),
              colorHex: Value(
                _subjectColors[title.hashCode.abs() % _subjectColors.length],
              ),
              isDeleted: const Value(false),
              updatedAt: now,
              syncStatus: const Value('pending_create'),
            ),
          );
    }

    for (final l in lessons) {
      final title = _clip(l.subject.trim(), 160);
      final subjectId = subjectIds[title];
      if (subjectId == null || l.startTime.compareTo(l.endTime) >= 0) continue;
      final id = UuidUtil.stable(
        userId,
        'college-lesson:$group:${l.dayOfWeek}:${l.pairNo}:${l.startTime}:'
        '${l.validFrom}:$title',
      );
      if (!keep.add(id)) continue;
      final row = LessonsCompanion(
        id: Value(id),
        subjectId: Value(subjectId),
        userId: Value(userId),
        dayOfWeek: Value(l.dayOfWeek),
        startTime: Value(l.startTime),
        endTime: Value(l.endTime),
        classroom: Value(_nullIfEmpty(l.room, 64)),
        lessonType: const Value('practice'),
        topic: const Value(null),
        isEvenWeek: const Value(null),
        specificDate: const Value(null),
        validFrom: Value(l.validFrom),
        validTo: Value(l.validTo),
        isCancelled: const Value(false),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      );
      final existing = await (db.select(
        db.lessons,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.lessons)
            .insert(row.copyWith(syncStatus: const Value('pending_create')));
      } else if (existing.isDeleted ||
          existing.classroom != row.classroom.value ||
          existing.endTime != l.endTime ||
          existing.validTo != l.validTo ||
          existing.subjectId != subjectId) {
        await (db.update(db.lessons)..where((t) => t.id.equals(id))).write(
          row.copyWith(syncStatus: Value(_pending(existing.syncStatus))),
        );
      }
    }

    // Pairs of the previous import that are gone (other group, new term).
    for (final id in previous) {
      if (keep.contains(id)) continue;
      final existing = await (db.select(
        db.lessons,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null || existing.isDeleted) continue;
      await (db.update(db.lessons)..where((t) => t.id.equals(id))).write(
        LessonsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          syncStatus: Value(_pending(existing.syncStatus)),
        ),
      );
    }
  });

  await prefs.setStringList(kCollegeTimetableIdsPrefsKey, keep.toList());
}

String _pending(String current) =>
    current == 'pending_create' ? 'pending_create' : 'pending_update';

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

String? _nullIfEmpty(String? s, int max) {
  final v = s?.trim();
  return v == null || v.isEmpty ? null : _clip(v, max);
}
