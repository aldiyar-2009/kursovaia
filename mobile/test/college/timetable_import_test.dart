import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/features/college/data/college_models.dart';
import 'package:studyplan/features/college/data/college_repository.dart';

CollegeLesson _l(int day, int pair, String start, String end, String subject,
        {String? room, String? teacher}) =>
    CollegeLesson(
      dayOfWeek: day,
      pairNo: pair,
      startTime: start,
      endTime: end,
      subject: subject,
      room: room,
      teacher: teacher,
      validFrom: '2026-09-01',
      validTo: '2026-11-23',
    );

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<List<Lesson>> liveLessons() => (db.select(db.lessons)
        ..where((t) => t.isDeleted.equals(false)))
      .get();

  test('imports pairs as pending subjects and lessons', () async {
    await applyTimetable(db, 'u1', 'ПО2501', [
      _l(1, 1, '08:00', '09:35', 'Базы данных', room: 'C1.3.240', teacher: 'Иванова А.'),
      _l(1, 2, '09:45', '11:20', 'Базы данных'),
      _l(2, 1, '08:00', '09:35', 'Алгоритмы'),
    ]);
    final subjects = await db.select(db.subjects).get();
    expect(subjects.map((s) => s.title).toSet(), {'Базы данных', 'Алгоритмы'});
    expect(subjects.firstWhere((s) => s.title == 'Базы данных').teacherName, 'Иванова А.');
    final lessons = await liveLessons();
    expect(lessons, hasLength(3));
    expect(lessons.every((l) => l.syncStatus == 'pending_create'), isTrue);
    expect(lessons.first.validFrom, '2026-09-01');
  });

  test('re-import keeps ids, adds no duplicates and deletes vanished pairs', () async {
    final first = [
      _l(1, 1, '08:00', '09:35', 'Базы данных'),
      _l(2, 1, '08:00', '09:35', 'Алгоритмы'),
    ];
    await applyTimetable(db, 'u1', 'ПО2501', first);
    final ids = (await liveLessons()).map((l) => l.id).toSet();

    await applyTimetable(db, 'u1', 'ПО2501', [first.first]);
    final live = await liveLessons();
    expect(live, hasLength(1));
    expect(ids.contains(live.single.id), isTrue);
    expect(await db.select(db.lessons).get(), hasLength(2)); // tombstone kept
    expect(await db.select(db.subjects).get(), hasLength(2));
  });

  test('reuses a subject the user already has with the same title', () async {
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 'own-subject',
          userId: 'u1',
          title: 'Базы данных',
          updatedAt: BigInt.one,
        ));
    await applyTimetable(db, 'u1', 'ПО2501', [_l(1, 1, '08:00', '09:35', 'базы данных')]);
    final lesson = (await liveLessons()).single;
    expect(lesson.subjectId, 'own-subject');
    expect(await db.select(db.subjects).get(), hasLength(1));
  });

  test('ids differ between users', () async {
    await applyTimetable(db, 'u1', 'ПО2501', [_l(1, 1, '08:00', '09:35', 'Алгоритмы')]);
    SharedPreferences.setMockInitialValues({});
    await applyTimetable(db, 'u2', 'ПО2501', [_l(1, 1, '08:00', '09:35', 'Алгоритмы')]);
    expect(await liveLessons(), hasLength(2));
  });
}
