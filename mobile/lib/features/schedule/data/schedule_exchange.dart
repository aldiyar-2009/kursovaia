import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/features/schedule/domain/schedule_rules.dart';

/// Format marker of exported timetables.
const kScheduleExchangeFormat = 'studyplan.schedule';

/// Own subjects and lessons of [userId] as pretty JSON:
/// `{format, version, exported_at, group_name, subjects, lessons}`.
Future<String> exportScheduleJson(
  AppDatabase db,
  String userId, {
  String? groupName,
  DateTime? now,
}) async {
  final subjects =
      await (db.select(db.subjects)
            ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .get();
  final lessons =
      await (db.select(db.lessons)
            ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm.asc(t.dayOfWeek),
              (t) => OrderingTerm.asc(t.startTime),
            ]))
          .get();
  final payload = {
    'format': kScheduleExchangeFormat,
    'version': 1,
    'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'group_name': groupName,
    'subjects': [
      for (final s in subjects)
        {
          'id': s.id,
          'title': s.title,
          'teacher_name': s.teacherName,
          'color_hex': s.colorHex,
        },
    ],
    'lessons': [
      for (final l in lessons)
        {
          'subject_id': l.subjectId,
          'day_of_week': l.dayOfWeek,
          'start_time': l.startTime,
          'end_time': l.endTime,
          'classroom': l.classroom,
          'lesson_type': l.lessonType,
          'topic': l.topic,
          'is_even_week': l.isEvenWeek,
          'specific_date': l.specificDate,
          'valid_from': l.validFrom,
          'valid_to': l.validTo,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// Adds the subjects and lessons of an exported [json] to [userId]'s
/// schedule. Subjects are matched by title (case-insensitive); lessons start
/// at [validFrom] (YYYY-MM-DD) unless they carry a later date. New rows are
/// pending, so the next sync uploads them. Returns the number of lessons.
///
/// Throws [FormatException] when [json] is not an exported timetable.
Future<int> importScheduleJson(
  AppDatabase db,
  String userId,
  String json, {
  String? validFrom,
}) async {
  final Object? decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic> ||
      decoded['subjects'] is! List ||
      decoded['lessons'] is! List) {
    throw const FormatException('not a timetable');
  }
  final rawSubjects = (decoded['subjects'] as List)
      .whereType<Map<String, dynamic>>();
  final rawLessons = (decoded['lessons'] as List)
      .whereType<Map<String, dynamic>>();
  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  var count = 0;

  await db.transaction(() async {
    final existing = await (db.select(
      db.subjects,
    )..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))).get();
    final byTitle = {for (final s in existing) s.title.toLowerCase(): s.id};
    final mapping = <String, String>{};

    for (final s in rawSubjects) {
      final title = (s['title'] ?? '').toString().trim();
      final origId = (s['id'] ?? '').toString();
      if (title.isEmpty || origId.isEmpty) continue;
      final known = byTitle[title.toLowerCase()];
      if (known != null) {
        mapping[origId] = known;
        continue;
      }
      final id = UuidUtil.generate();
      mapping[origId] = id;
      byTitle[title.toLowerCase()] = id;
      final color = s['color_hex'];
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: id,
              userId: userId,
              title: title.length > 160 ? title.substring(0, 160) : title,
              teacherName: Value(_str(s['teacher_name'], 160)),
              colorHex: Value(
                color is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)
                    ? color
                    : null,
              ),
              updatedAt: now,
              syncStatus: const Value('pending_create'),
            ),
          );
    }

    for (final l in rawLessons) {
      final subjectId = mapping[(l['subject_id'] ?? '').toString()];
      final day = l['day_of_week'];
      final start = l['start_time'];
      final end = l['end_time'];
      if (subjectId == null ||
          day is! num ||
          day < 1 ||
          day > 7 ||
          start is! String ||
          end is! String ||
          !_time.hasMatch(start) ||
          !_time.hasMatch(end) ||
          start.compareTo(end) >= 0) {
        continue;
      }
      final type = l['lesson_type'];
      final from = _laterDate(_date(l['valid_from']), validFrom);
      await db
          .into(db.lessons)
          .insert(
            LessonsCompanion.insert(
              id: UuidUtil.generate(),
              subjectId: subjectId,
              userId: userId,
              dayOfWeek: day.toInt(),
              startTime: start,
              endTime: end,
              classroom: Value(_str(l['classroom'], 64)),
              lessonType: Value(
                const ['lecture', 'practice', 'lab'].contains(type)
                    ? type as String
                    : 'lecture',
              ),
              topic: Value(_str(l['topic'], 255)),
              isEvenWeek: Value(
                l['is_even_week'] is bool ? l['is_even_week'] as bool : null,
              ),
              specificDate: Value(_date(l['specific_date'])),
              validFrom: Value(from),
              validTo: Value(_date(l['valid_to'])),
              updatedAt: now,
              syncStatus: const Value('pending_create'),
            ),
          );
      count++;
    }
  });
  return count;
}

/// Today as YYYY-MM-DD (default «valid from» of an import).
String todayKey() => dateKey(DateTime.now());

final _time = RegExp(r'^\d{2}:\d{2}$');
final _ymd = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String? _date(Object? v) => v is String && _ymd.hasMatch(v) ? v : null;

String? _laterDate(String? a, String? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.compareTo(b) >= 0 ? a : b;
}

String? _str(Object? v, int max) {
  if (v is! String) return null;
  final s = v.trim();
  if (s.isEmpty) return null;
  return s.length > max ? s.substring(0, max) : s;
}
