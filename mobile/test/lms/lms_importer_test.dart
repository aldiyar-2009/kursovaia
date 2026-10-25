import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/features/lms/data/lms_importer.dart';
import 'package:studyplan/features/lms/data/lms_models.dart';

void main() {
  const user = 'u1';
  final now = DateTime(2026, 10, 26, 12);
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
  });

  LmsCourseData course(int id, String title, {double? total}) => LmsCourseData(
    lmsCourseId: id,
    title: title,
    teacherName: 'Teacher $id',
    classification: 'inprogress',
    total: total,
  );

  LmsEventData event(
    int? id,
    String title,
    LmsEventType type,
    DateTime startsAt,
  ) => LmsEventData(
    lmsEventId: id,
    lmsCourseId: 1,
    title: title,
    courseTitle: 'Algebra',
    type: type,
    startsAt: startsAt,
  );

  LmsMaterialData material(int id, String title) => LmsMaterialData(
    lmsModuleId: id,
    lmsCourseId: 1,
    courseTitle: 'Algebra',
    sectionTitle: 'Week 1',
    title: title,
    materialType: 'file',
  );

  final future1 = now.add(const Duration(days: 3));
  final future2 = now.add(const Duration(days: 10));
  final past1 = now.subtract(const Duration(days: 5));

  LmsImportResult firstResult() => LmsImportResult(
    courses: [
      course(1, 'Algebra', total: 80),
      course(2, 'Physics'),
      course(3, 'History'),
    ],
    events: [
      event(100, 'Essay', LmsEventType.deadline, future1),
      event(101, 'Lab report', LmsEventType.deadline, future2),
      event(200, 'Lecture past', LmsEventType.classSession, past1),
      event(201, 'Lecture future', LmsEventType.classSession, future1),
    ],
    materials: [material(10, 'Slides 1'), material(11, 'Slides 2')],
    profile: const LmsProfileData(
      fullName: 'Student Test',
      email: 's@astanait.edu.kz',
      lmsUserId: 42,
    ),
  );

  Future<List<LmsCourse>> allCourses() => db.select(db.lmsCourses).get();
  Future<List<LmsEvent>> allEvents() => db.select(db.lmsEvents).get();
  Future<List<LmsMaterial>> allMaterials() => db.select(db.lmsMaterials).get();
  Future<List<Subject>> allSubjects() => db.select(db.subjects).get();

  LmsCourse byLmsId(List<LmsCourse> list, int id) =>
      list.singleWhere((c) => c.lmsCourseId == id);
  LmsEvent eventById(List<LmsEvent> list, int id) =>
      list.singleWhere((e) => e.lmsEventId == id);

  test('first import creates courses, events, materials and subjects, all pending', () async {
    final summary = await applyImport(db, user, firstResult(), now: now);

    expect(summary.courses, 3);
    expect(summary.events, 4);
    expect(summary.classes, 2);
    expect(summary.materials, 2);
    expect(summary.errors, isEmpty);

    final courses = await allCourses();
    expect(courses, hasLength(3));
    expect(courses.every((c) => c.source == 'lms'), isTrue);
    expect(courses.every((c) => c.userId == user), isTrue);
    expect(courses.every((c) => c.syncStatus == 'pending_create'), isTrue);
    expect(courses.every((c) => c.credits == 5), isTrue);
    expect(courses.every((c) => c.updatedAt == BigInt.from(now.millisecondsSinceEpoch)), isTrue);
    expect(courses.every((c) => c.importedAt == BigInt.from(now.millisecondsSinceEpoch)), isTrue);
    final algebra = byLmsId(courses, 1);
    expect(algebra.total, 80);
    expect(algebra.teacherName, 'Teacher 1');
    expect(byLmsId(courses, 2).total, isNull);

    final subjects = await allSubjects();
    expect(subjects.map((s) => s.title).toSet(), {'Algebra', 'Physics', 'History'});
    expect(subjects.every((s) => s.syncStatus == 'pending_create'), isTrue);
    expect(subjects.every((s) => s.userId == user && s.colorHex != null), isTrue);
    for (final c in courses) {
      final s = subjects.singleWhere((s) => s.id == c.subjectId);
      expect(s.title, c.title);
    }

    final events = await allEvents();
    expect(events, hasLength(4));
    expect(events.every((e) => e.syncStatus == 'pending_create'), isTrue);
    expect(eventById(events, 200).eventType, 'class');
    expect(eventById(events, 100).eventType, 'deadline');
    expect(eventById(events, 100).startsAt, BigInt.from(future1.millisecondsSinceEpoch));

    final materials = await allMaterials();
    expect(materials, hasLength(2));
    expect(materials.every((m) => m.syncStatus == 'pending_create'), isTrue);
  });

  test('re-import keeps credits, isDone and manual courses; removed course is deleted', () async {
    await applyImport(db, user, firstResult(), now: now);

    final courses = await allCourses();
    await db.lmsDao.updateCredits(byLmsId(courses, 1).id, 3);
    final events = await allEvents();
    await db.lmsDao.setEventDone(eventById(events, 100).id, true);
    await db.lmsDao.upsertManualCourse(
      const LmsCoursesCompanion(
        id: Value('manual-1'),
        userId: Value(user),
        source: Value('manual'),
        title: Value('Elective'),
        total: Value(70),
      ),
    );

    final later = now.add(const Duration(hours: 1));
    final second = LmsImportResult(
      courses: [course(1, 'Algebra', total: 90), course(2, 'Physics')],
      events: firstResult().events,
      materials: firstResult().materials,
    );
    final summary = await applyImport(db, user, second, now: later);
    expect(summary.courses, 2);

    final after = await allCourses();
    expect(after, hasLength(4));
    final algebra = byLmsId(after, 1);
    expect(algebra.credits, 3);
    expect(algebra.total, 90);
    expect(algebra.isDeleted, isFalse);
    expect(algebra.updatedAt, BigInt.from(later.millisecondsSinceEpoch));
    final history = byLmsId(after, 3);
    expect(history.isDeleted, isTrue);
    expect(history.syncStatus, 'pending_delete');
    final manual = after.singleWhere((c) => c.id == 'manual-1');
    expect(manual.isDeleted, isFalse);
    expect(manual.total, 70);
    expect(manual.title, 'Elective');

    final eventsAfter = await allEvents();
    expect(eventsAfter, hasLength(4));
    expect(eventById(eventsAfter, 100).isDone, isTrue);
    expect(eventById(eventsAfter, 101).isDone, isFalse);

    // No duplicate subjects on re-import.
    expect(await allSubjects(), hasLength(3));
    expect(await allMaterials(), hasLength(2));
  });

  test('errors[courses] set -> no course deletions', () async {
    await applyImport(db, user, firstResult(), now: now);
    final summary = await applyImport(
      db,
      user,
      const LmsImportResult(errors: {'courses': 'failed'}),
      now: now.add(const Duration(hours: 1)),
    );
    expect(summary.errors, {'courses': 'failed'});
    final courses = await allCourses();
    expect(courses, hasLength(3));
    expect(courses.any((c) => c.isDeleted), isFalse);
  });

  test('errors[materials] set -> no material deletions; otherwise missing ones deleted', () async {
    await applyImport(db, user, firstResult(), now: now);
    await applyImport(
      db,
      user,
      LmsImportResult(courses: firstResult().courses, errors: const {'materials': 'x'}),
      now: now,
    );
    expect((await allMaterials()).any((m) => m.isDeleted), isFalse);

    await applyImport(
      db,
      user,
      LmsImportResult(courses: firstResult().courses, materials: [material(10, 'Slides 1')]),
      now: now,
    );
    final materials = await allMaterials();
    expect(materials.singleWhere((m) => m.lmsModuleId == 11).isDeleted, isTrue);
    expect(materials.singleWhere((m) => m.lmsModuleId == 11).syncStatus, 'pending_delete');
    expect(materials.singleWhere((m) => m.lmsModuleId == 10).isDeleted, isFalse);
  });

  test('missing past class stays, missing future class is deleted', () async {
    await applyImport(db, user, firstResult(), now: now);
    final second = LmsImportResult(
      courses: firstResult().courses,
      events: [
        event(100, 'Essay', LmsEventType.deadline, future1),
        event(101, 'Lab report', LmsEventType.deadline, future2),
      ],
    );
    final summary = await applyImport(db, user, second, now: now);
    expect(summary.classes, 0);

    final events = await allEvents();
    expect(eventById(events, 200).isDeleted, isFalse);
    expect(eventById(events, 201).isDeleted, isTrue);
    expect(eventById(events, 201).syncStatus, 'pending_delete');
    expect(eventById(events, 100).isDeleted, isFalse);
  });

  test('a kind imported with an error deletes nothing of that type', () async {
    await applyImport(db, user, firstResult(), now: now);
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: firstResult().courses,
        errors: const {'deadlines': 'x', 'classes': 'y'},
      ),
      now: now,
    );
    expect((await allEvents()).any((e) => e.isDeleted), isFalse);
  });

  test('events without id are matched by type, title and start', () async {
    final r = LmsImportResult(
      events: [event(null, 'Attendance', LmsEventType.classSession, future1)],
    );
    await applyImport(db, user, r, now: now);
    await applyImport(db, user, r, now: now);
    expect(await allEvents(), hasLength(1));
  });

  test('existing subject with the same title (other case) is linked, not duplicated', () async {
    await db.into(db.subjects).insert(
      SubjectsCompanion.insert(
        id: 's1',
        userId: user,
        title: '  algebra ',
        updatedAt: BigInt.from(1),
      ),
    );
    await applyImport(
      db,
      user,
      LmsImportResult(courses: [course(1, 'Algebra')]),
      now: now,
    );
    final subjects = await allSubjects();
    expect(subjects, hasLength(1));
    expect((await allCourses()).single.subjectId, 's1');
  });

  test('errors[grades] set -> existing scores are kept', () async {
    await applyImport(db, user, firstResult(), now: now);
    await applyImport(
      db,
      user,
      LmsImportResult(courses: [course(1, 'Algebra')], errors: const {'grades': 'x'}),
      now: now,
    );
    expect(byLmsId(await allCourses(), 1).total, 80);
  });

  test('errors[courses] set -> materials are not deleted either', () async {
    await applyImport(db, user, firstResult(), now: now);
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: [course(1, 'Algebra')],
        materialCourseIds: const {1},
        errors: const {'courses': 'partial'},
      ),
      now: now,
    );
    expect((await allMaterials()).any((m) => m.isDeleted), isFalse);
    expect((await allCourses()).any((c) => c.isDeleted), isFalse);
  });

  test('material deletions are scoped to courses whose contents loaded', () async {
    final physics = LmsMaterialData(
      lmsModuleId: 20,
      lmsCourseId: 2,
      courseTitle: 'Physics',
      title: 'Physics notes',
      materialType: 'file',
    );
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: firstResult().courses,
        materials: [material(10, 'Slides 1'), material(11, 'Slides 2'), physics],
      ),
      now: now,
    );
    // Only course 1 loaded; its module 11 is gone. Course 2 was not fetched.
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: firstResult().courses,
        materials: [material(10, 'Slides 1')],
        materialCourseIds: const {1},
      ),
      now: now,
    );
    final materials = await allMaterials();
    expect(materials.singleWhere((m) => m.lmsModuleId == 11).isDeleted, isTrue);
    expect(materials.singleWhere((m) => m.lmsModuleId == 20).isDeleted, isFalse);
    expect(materials.singleWhere((m) => m.lmsModuleId == 10).isDeleted, isFalse);
  });

  test('failedGradeCourseIds keeps existing scores of those courses only', () async {
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: [course(1, 'Algebra', total: 80), course(2, 'Physics', total: 60)],
      ),
      now: now,
    );
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: [course(1, 'Algebra'), course(2, 'Physics')],
        failedGradeCourseIds: const {1},
      ),
      now: now,
    );
    final courses = await allCourses();
    expect(byLmsId(courses, 1).total, 80);
    expect(byLmsId(courses, 2).total, isNull);
  });

  test('failed grade course still takes a new non-null score', () async {
    await applyImport(
      db,
      user,
      LmsImportResult(courses: [course(1, 'Algebra', total: 80)]),
      now: now,
    );
    await applyImport(
      db,
      user,
      LmsImportResult(
        courses: [course(1, 'Algebra', total: 85)],
        failedGradeCourseIds: const {1},
      ),
      now: now,
    );
    expect(byLmsId(await allCourses(), 1).total, 85);
  });

  test('vanished future/recent deadline is marked done, old one untouched', () async {
    final recentPast = now.subtract(const Duration(days: 5));
    final oldPast = now.subtract(const Duration(days: 60));
    await applyImport(
      db,
      user,
      LmsImportResult(
        events: [
          event(100, 'Essay', LmsEventType.deadline, future1),
          event(101, 'Lab report', LmsEventType.deadline, future2),
          event(102, 'Quiz', LmsEventType.deadline, recentPast),
          event(103, 'Old quiz', LmsEventType.deadline, oldPast),
        ],
      ),
      now: now,
    );
    final synced = await allEvents();
    for (final e in synced) {
      await (db.update(db.lmsEvents)..where((t) => t.id.equals(e.id)))
          .write(const LmsEventsCompanion(syncStatus: Value('synced')));
    }

    await applyImport(
      db,
      user,
      LmsImportResult(
        events: [event(101, 'Lab report', LmsEventType.deadline, future2)],
      ),
      now: now,
    );
    final events = await allEvents();
    final essay = eventById(events, 100);
    expect(essay.isDeleted, isFalse);
    expect(essay.isDone, isTrue);
    expect(essay.syncStatus, 'pending_update');
    final quiz = eventById(events, 102);
    expect(quiz.isDeleted, isFalse);
    expect(quiz.isDone, isTrue);
    final old = eventById(events, 103);
    expect(old.isDeleted, isFalse);
    expect(old.isDone, isFalse);
    expect(old.syncStatus, 'synced');
    expect(eventById(events, 101).isDone, isFalse);
  });

  test('vanished deadline with deadlines error is left alone', () async {
    await applyImport(
      db,
      user,
      LmsImportResult(events: [event(100, 'Essay', LmsEventType.deadline, future1)]),
      now: now,
    );
    await applyImport(
      db,
      user,
      const LmsImportResult(errors: {'deadlines': 'x'}),
      now: now,
    );
    final e = eventById(await allEvents(), 100);
    expect(e.isDone, isFalse);
    expect(e.isDeleted, isFalse);
  });

  test('profile is stored in SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    await applyImport(db, user, firstResult(), now: now, prefs: prefs);
    final stored = jsonDecode(prefs.getString('lms.profile')!) as Map<String, dynamic>;
    expect(stored['fullName'], 'Student Test');
    expect(stored['lmsUserId'], 42);
  });
}
