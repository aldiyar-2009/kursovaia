/// Applies an [LmsImportResult] to the local drift database.
///
/// Rules (spec «Этап 4», plan Task E1):
/// * Courses are upserted by `lmsCourseId` among the user's `lms` rows.
///   `credits` is never overwritten; title, teacher, classification, scores,
///   grade items and `importedAt` are. `manual` courses are never touched.
///   `lms` courses missing from the result are soft-deleted, unless
///   `errors['courses']` is set (then nothing is deleted).
/// * Scores: with `errors['grades']` stored scores are kept; for a course in
///   `failedGradeCourseIds` a stored score is replaced only by a non-null one.
/// * Each imported course is linked to a subject with the same title
///   (case-insensitive, trimmed); a subject is created when none exists.
/// * Events are upserted by `lmsEventId` (without an id: by type + title +
///   start); `isDone` is kept. For each kind imported without an error
///   (`deadlines`, `classes`): missing future classes are soft-deleted; a
///   missing deadline due in the future or within [kLmsSubmittedGrace] is
///   marked done (Moodle drops submitted work from the action events). Older
///   past events stay as history.
/// * Materials are upserted by `lmsModuleId`; missing ones are soft-deleted
///   only when neither `errors['materials']` nor `errors['courses']` is set,
///   and only for courses in `materialCourseIds` (contents loaded OK).
/// * Every write stamps `updatedAt = now` and a pending `syncStatus`.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/features/lms/data/lms_models.dart';

/// SharedPreferences key holding the LMS profile JSON (device only).
const kLmsProfilePrefsKey = 'lms.profile';

/// A deadline that vanished from the LMS is marked done when it is due in the
/// future or at most this long ago; older ones are left untouched.
const kLmsSubmittedGrace = Duration(days: 30);

/// Neutral colours for subjects created by the import.
const _subjectPalette = [
  '#64748B',
  '#6B7280',
  '#78716C',
  '#5B7083',
  '#6E7F80',
  '#7C7A8C',
];

class LmsImportSummary {
  const LmsImportSummary({
    required this.courses,
    required this.events,
    required this.classes,
    required this.materials,
    required this.errors,
  });

  final int courses;

  /// All imported events, classes included.
  final int events;
  final int classes;
  final int materials;
  final Map<String, String> errors;
}

String _normTitle(String s) => s.trim().toLowerCase();

String _paletteColor(String title) {
  var sum = 0;
  for (final c in title.codeUnits) {
    sum = (sum + c) & 0x7fffffff;
  }
  return _subjectPalette[sum % _subjectPalette.length];
}

/// A row that has never reached the server stays `pending_create`.
String _updateStatus(String current) =>
    current == 'pending_create' ? 'pending_create' : 'pending_update';

String _truncate(String s, int max) => s.length <= max ? s : s.substring(0, max);

String? _truncateOpt(String? s, int max) => s == null ? null : _truncate(s, max);

Future<LmsImportSummary> applyImport(
  AppDatabase db,
  String userId,
  LmsImportResult r, {
  required DateTime now,
  SharedPreferences? prefs,
}) async {
  final nowMs = BigInt.from(now.millisecondsSinceEpoch);
  final errors = Map<String, String>.unmodifiable(r.errors);
  var courseCount = 0;
  var eventCount = 0;
  var classCount = 0;
  var materialCount = 0;

  await db.transaction(() async {
    // ---- subjects (for linking) ----
    final subjects = await (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .get();
    final subjectByTitle = <String, String>{};
    for (final s in subjects) {
      subjectByTitle.putIfAbsent(_normTitle(s.title), () => s.id);
    }
    final liveSubjectIds = subjects.map((s) => s.id).toSet();

    Future<String> subjectFor(LmsCourseData c) async {
      final title = _truncate(c.title.trim(), 160);
      final key = _normTitle(title);
      final existing = subjectByTitle[key];
      if (existing != null) return existing;
      final id = UuidUtil.generate();
      await db.into(db.subjects).insert(SubjectsCompanion.insert(
        id: id,
        userId: userId,
        title: title,
        teacherName: Value(_truncateOpt(c.teacherName, 160)),
        colorHex: Value(_paletteColor(key)),
        updatedAt: nowMs,
        syncStatus: const Value('pending_create'),
      ));
      subjectByTitle[key] = id;
      liveSubjectIds.add(id);
      return id;
    }

    // ---- courses ----
    final lmsCourses = await (db.select(db.lmsCourses)
          ..where((t) => t.userId.equals(userId) & t.source.equals('lms')))
        .get();
    final courseByLmsId = <int, LmsCourse>{};
    for (final c in lmsCourses) {
      final id = c.lmsCourseId;
      if (id == null) continue;
      final prev = courseByLmsId[id];
      // Prefer a live row over a tombstone when both exist.
      if (prev == null || (prev.isDeleted && !c.isDeleted)) courseByLmsId[id] = c;
    }
    final gradesFailed = errors.containsKey('grades');
    final importedCourseIds = <int>{};

    for (final c in r.courses) {
      if (c.title.trim().isEmpty) continue;
      importedCourseIds.add(c.lmsCourseId);
      final existing = courseByLmsId[c.lmsCourseId];
      final title = _truncate(c.title.trim(), 255);
      // Keep a link to a subject that still exists (the user may have renamed
      // it); otherwise link by title or create one.
      final subjectId =
          existing?.subjectId != null && liveSubjectIds.contains(existing!.subjectId)
              ? existing.subjectId!
              : await subjectFor(c);
      // All grades failed: keep every stored score. This course's report
      // failed: keep a stored score unless a new non-null one arrived (e.g. the
      // overview total).
      final keepAll = gradesFailed && existing != null;
      final keepMissing =
          existing != null && r.failedGradeCourseIds.contains(c.lmsCourseId);
      Value<T?> score<T>(T? v) => keepAll || (keepMissing && v == null)
          ? Value<T?>.absent()
          : Value<T?>(v);
      final companion = LmsCoursesCompanion(
        source: const Value('lms'),
        lmsCourseId: Value(c.lmsCourseId),
        subjectId: Value(subjectId),
        classification: Value(c.classification),
        title: Value(title),
        teacherName: Value(_truncateOpt(c.teacherName, 160)),
        registerMidterm: score(c.midterm),
        registerEndterm: score(c.endterm),
        finalExam: score(c.finalExam),
        total: score(c.total),
        gradeItemsJson: score(c.gradeItemsJson),
        importedAt: Value(nowMs),
        isDeleted: const Value(false),
        updatedAt: Value(nowMs),
      );
      if (existing == null) {
        final id = UuidUtil.generate();
        await db.into(db.lmsCourses).insert(companion.copyWith(
          id: Value(id),
          userId: Value(userId),
          credits: const Value(5),
          syncStatus: const Value('pending_create'),
        ));
        final row = await (db.select(db.lmsCourses)..where((t) => t.id.equals(id))).getSingle();
        courseByLmsId[c.lmsCourseId] = row;
      } else {
        await (db.update(db.lmsCourses)..where((t) => t.id.equals(existing.id))).write(
          companion.copyWith(syncStatus: Value(_updateStatus(existing.syncStatus))),
        );
      }
      courseCount++;
    }

    if (!errors.containsKey('courses')) {
      for (final c in lmsCourses) {
        if (c.isDeleted) continue;
        if (c.lmsCourseId != null && importedCourseIds.contains(c.lmsCourseId)) continue;
        await (db.update(db.lmsCourses)..where((t) => t.id.equals(c.id))).write(
          LmsCoursesCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(nowMs),
            syncStatus: const Value('pending_delete'),
          ),
        );
      }
    }

    // ---- events ----
    final existingEvents = await (db.select(db.lmsEvents)
          ..where((t) => t.userId.equals(userId)))
        .get();
    String naturalKey(String type, String title, BigInt startsAt) =>
        '$type|$title|$startsAt';
    final eventById = <int, LmsEvent>{};
    final eventByKey = <String, LmsEvent>{};
    for (final e in existingEvents) {
      if (e.lmsEventId != null) {
        final prev = eventById[e.lmsEventId!];
        if (prev == null || (prev.isDeleted && !e.isDeleted)) eventById[e.lmsEventId!] = e;
      } else {
        eventByKey.putIfAbsent(naturalKey(e.eventType, e.title, e.startsAt), () => e);
      }
    }
    final touchedEventIds = <String>{};

    for (final e in r.events) {
      if (e.title.trim().isEmpty) continue;
      final type = e.type.storageValue;
      final title = _truncate(e.title.trim(), 255);
      final startsAt = BigInt.from(e.startsAt.millisecondsSinceEpoch);
      final key = naturalKey(type, title, startsAt);
      final existing = e.lmsEventId != null ? eventById[e.lmsEventId!] : eventByKey[key];
      final companion = LmsEventsCompanion(
        lmsEventId: Value(e.lmsEventId),
        lmsCourseId: Value(e.lmsCourseId),
        title: Value(title),
        courseTitle: Value(_truncateOpt(e.courseTitle, 255)),
        eventType: Value(type),
        moduleName: Value(_truncateOpt(e.moduleName, 64)),
        startsAt: Value(startsAt),
        durationMin: Value(e.durationMin),
        location: Value(_truncateOpt(e.location, 128)),
        url: Value(_truncateOpt(e.url, 1024)),
        importedAt: Value(nowMs),
        isDeleted: const Value(false),
        updatedAt: Value(nowMs),
      );
      if (existing == null) {
        final id = UuidUtil.generate();
        await db.into(db.lmsEvents).insert(companion.copyWith(
          id: Value(id),
          userId: Value(userId),
          isDone: const Value(false),
          syncStatus: const Value('pending_create'),
        ));
        final row = await (db.select(db.lmsEvents)..where((t) => t.id.equals(id))).getSingle();
        if (e.lmsEventId != null) {
          eventById[e.lmsEventId!] = row;
        } else {
          eventByKey[key] = row;
        }
        touchedEventIds.add(id);
      } else {
        await (db.update(db.lmsEvents)..where((t) => t.id.equals(existing.id))).write(
          companion.copyWith(syncStatus: Value(_updateStatus(existing.syncStatus))),
        );
        touchedEventIds.add(existing.id);
      }
      eventCount++;
      if (e.type == LmsEventType.classSession) classCount++;
    }

    final deletableTypes = <String>{
      if (!errors.containsKey('deadlines')) LmsEventType.deadline.storageValue,
      if (!errors.containsKey('classes')) LmsEventType.classSession.storageValue,
    };
    final doneSinceMs = BigInt.from(
      now.subtract(kLmsSubmittedGrace).millisecondsSinceEpoch,
    );
    for (final e in existingEvents) {
      if (e.isDeleted || touchedEventIds.contains(e.id)) continue;
      if (!deletableTypes.contains(e.eventType)) continue;
      if (e.eventType == LmsEventType.deadline.storageValue) {
        // Moodle drops submitted assignments from the action events: a
        // vanished deadline is marked done, not deleted. Old ones stay as is.
        if (e.isDone || e.startsAt < doneSinceMs) continue;
        await (db.update(db.lmsEvents)..where((t) => t.id.equals(e.id))).write(
          LmsEventsCompanion(
            isDone: const Value(true),
            updatedAt: Value(nowMs),
            syncStatus: Value(_updateStatus(e.syncStatus)),
          ),
        );
        continue;
      }
      if (e.startsAt < nowMs) continue; // past events stay as history
      await (db.update(db.lmsEvents)..where((t) => t.id.equals(e.id))).write(
        LmsEventsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(nowMs),
          syncStatus: const Value('pending_delete'),
        ),
      );
    }

    // ---- materials ----
    final existingMaterials = await (db.select(db.lmsMaterials)
          ..where((t) => t.userId.equals(userId)))
        .get();
    String materialKey(int? courseId, String? section, String title) =>
        '$courseId|$section|$title';
    final materialById = <int, LmsMaterial>{};
    final materialByKey = <String, LmsMaterial>{};
    for (final m in existingMaterials) {
      if (m.lmsModuleId != null) {
        final prev = materialById[m.lmsModuleId!];
        if (prev == null || (prev.isDeleted && !m.isDeleted)) materialById[m.lmsModuleId!] = m;
      } else {
        materialByKey.putIfAbsent(
          materialKey(m.lmsCourseId, m.sectionTitle, m.title),
          () => m,
        );
      }
    }
    final touchedMaterialIds = <String>{};

    for (final m in r.materials) {
      if (m.title.trim().isEmpty) continue;
      final title = _truncate(m.title.trim(), 255);
      final section = _truncateOpt(m.sectionTitle, 255);
      final key = materialKey(m.lmsCourseId, section, title);
      final existing = m.lmsModuleId != null ? materialById[m.lmsModuleId!] : materialByKey[key];
      final companion = LmsMaterialsCompanion(
        lmsModuleId: Value(m.lmsModuleId),
        lmsCourseId: Value(m.lmsCourseId),
        courseTitle: Value(_truncateOpt(m.courseTitle, 255)),
        sectionTitle: Value(section),
        title: Value(title),
        materialType: Value(m.materialType),
        url: Value(_truncateOpt(m.url, 1024)),
        importedAt: Value(nowMs),
        isDeleted: const Value(false),
        updatedAt: Value(nowMs),
      );
      if (existing == null) {
        final id = UuidUtil.generate();
        await db.into(db.lmsMaterials).insert(companion.copyWith(
          id: Value(id),
          userId: Value(userId),
          syncStatus: const Value('pending_create'),
        ));
        final row = await (db.select(db.lmsMaterials)..where((t) => t.id.equals(id))).getSingle();
        if (m.lmsModuleId != null) {
          materialById[m.lmsModuleId!] = row;
        } else {
          materialByKey[key] = row;
        }
        touchedMaterialIds.add(id);
      } else {
        await (db.update(db.lmsMaterials)..where((t) => t.id.equals(existing.id))).write(
          companion.copyWith(syncStatus: Value(_updateStatus(existing.syncStatus))),
        );
        touchedMaterialIds.add(existing.id);
      }
      materialCount++;
    }

    if (!errors.containsKey('materials') && !errors.containsKey('courses')) {
      final loadedCourses =
          r.materialCourseIds ??
          {for (final m in r.materials) ?m.lmsCourseId};
      for (final m in existingMaterials) {
        if (m.isDeleted || touchedMaterialIds.contains(m.id)) continue;
        if (!loadedCourses.contains(m.lmsCourseId)) continue;
        await (db.update(db.lmsMaterials)..where((t) => t.id.equals(m.id))).write(
          LmsMaterialsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(nowMs),
            syncStatus: const Value('pending_delete'),
          ),
        );
      }
    }
  });

  final profile = r.profile;
  if (profile != null && prefs != null) {
    await prefs.setString(kLmsProfilePrefsKey, jsonEncode(profile.toJson()));
  }

  return LmsImportSummary(
    courses: courseCount,
    events: eventCount,
    classes: classCount,
    materials: materialCount,
    errors: errors,
  );
}
