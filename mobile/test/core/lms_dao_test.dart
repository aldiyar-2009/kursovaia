import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/lms_dao.dart';

void main() {
  late AppDatabase db;
  late LmsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.lmsDao;
  });

  tearDown(() async {
    await db.close();
  });

  LmsCoursesCompanion manualCourse(String id, String title, {String userId = 'u1'}) {
    return LmsCoursesCompanion(
      id: Value(id),
      userId: Value(userId),
      source: const Value('manual'),
      title: Value(title),
    );
  }

  test('manual course insert appears in watchCourses and is pending_create', () async {
    await dao.upsertManualCourse(manualCourse('c2', 'Physics'));
    await dao.upsertManualCourse(manualCourse('c1', 'Algebra'));
    await dao.upsertManualCourse(manualCourse('c3', 'Other user', userId: 'u2'));

    final courses = await dao.watchCourses('u1').first;
    expect(courses.map((c) => c.title), ['Algebra', 'Physics']);
    expect(courses.every((c) => c.syncStatus == 'pending_create'), isTrue);
    expect(courses.first.credits, 5);
    expect(courses.first.total, isNull);
    expect(courses.first.updatedAt > BigInt.zero, isTrue);
  });

  test('upsertManualCourse on an existing synced course marks it pending_update', () async {
    await dao.upsertManualCourse(manualCourse('c1', 'Algebra'));
    await (db.update(db.lmsCourses)..where((t) => t.id.equals('c1')))
        .write(const LmsCoursesCompanion(syncStatus: Value('synced')));

    await dao.upsertManualCourse(manualCourse('c1', 'Linear Algebra'));

    final course = (await dao.watchCourses('u1').first).single;
    expect(course.title, 'Linear Algebra');
    expect(course.syncStatus, 'pending_update');
  });

  test('updateCredits changes credits and marks pending_update', () async {
    await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
          id: 'c1',
          userId: 'u1',
          source: const Value('lms'),
          lmsCourseId: const Value(42),
          title: 'Algebra',
          updatedAt: BigInt.from(1),
        ));

    await dao.updateCredits('c1', 7);

    final course = (await dao.watchCourses('u1').first).single;
    expect(course.credits, 7);
    expect(course.syncStatus, 'pending_update');
    expect(course.updatedAt > BigInt.one, isTrue);
  });

  test('softDeleteCourse hides course and marks pending_delete', () async {
    await dao.upsertManualCourse(manualCourse('c1', 'Algebra'));
    await dao.softDeleteCourse('c1');

    expect(await dao.watchCourses('u1').first, isEmpty);
    final row = await (db.select(db.lmsCourses)..where((t) => t.id.equals('c1'))).getSingle();
    expect(row.isDeleted, isTrue);
    expect(row.syncStatus, 'pending_delete');
  });

  test('watchEvents filters by type and range, setEventDone marks pending', () async {
    Future<void> addEvent(String id, String type, int startsAt) {
      return db.into(db.lmsEvents).insert(LmsEventsCompanion.insert(
            id: id,
            userId: 'u1',
            title: 'Event $id',
            eventType: Value(type),
            startsAt: BigInt.from(startsAt),
            updatedAt: BigInt.from(1),
          ));
    }

    await addEvent('e1', 'deadline', 3000);
    await addEvent('e2', 'class', 2000);
    await addEvent('e3', 'deadline', 1000);

    final all = await dao.watchEvents('u1').first;
    expect(all.map((e) => e.id), ['e3', 'e2', 'e1']);

    final deadlines = await dao.watchEvents('u1', type: 'deadline', fromMs: 2000, toMs: 5000).first;
    expect(deadlines.map((e) => e.id), ['e1']);

    await dao.setEventDone('e1', true);
    final e1 = await (db.select(db.lmsEvents)..where((t) => t.id.equals('e1'))).getSingle();
    expect(e1.isDone, isTrue);
    expect(e1.syncStatus, 'pending_update');
  });

  test('watchMaterials returns only non-deleted materials of the user', () async {
    await db.into(db.lmsMaterials).insert(LmsMaterialsCompanion.insert(
          id: 'm1',
          userId: 'u1',
          title: 'Lecture 1',
          materialType: const Value('file'),
          updatedAt: BigInt.from(1),
        ));
    await db.into(db.lmsMaterials).insert(LmsMaterialsCompanion.insert(
          id: 'm2',
          userId: 'u1',
          title: 'Deleted',
          isDeleted: const Value(true),
          updatedAt: BigInt.from(1),
        ));

    final materials = await dao.watchMaterials('u1').first;
    expect(materials.map((m) => m.id), ['m1']);
    expect(materials.single.materialType, 'file');
  });
}
