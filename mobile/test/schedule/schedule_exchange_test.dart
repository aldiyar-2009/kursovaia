import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/features/schedule/data/schedule_exchange.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(String userId) async {
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 's1',
          userId: userId,
          title: 'Web',
          updatedAt: BigInt.one,
        ));
    await db.into(db.lessons).insert(LessonsCompanion.insert(
          id: 'l1',
          subjectId: 's1',
          userId: userId,
          dayOfWeek: 2,
          startTime: '10:00',
          endTime: '11:20',
          updatedAt: BigInt.one,
        ));
  }

  test('export contains own subjects and lessons', () async {
    await seed('a');
    final json = jsonDecode(await exportScheduleJson(db, 'a', groupName: 'SE-2401'))
        as Map<String, dynamic>;
    expect(json['format'], kScheduleExchangeFormat);
    expect(json['group_name'], 'SE-2401');
    expect((json['subjects'] as List).single['title'], 'Web');
    expect((json['lessons'] as List).single['start_time'], '10:00');
  });

  test('import into another user creates pending rows from validFrom', () async {
    await seed('a');
    final json = await exportScheduleJson(db, 'a');
    final count = await importScheduleJson(db, 'b', json, validFrom: '2026-11-02');
    expect(count, 1);
    final lessons = await (db.select(db.lessons)..where((t) => t.userId.equals('b'))).get();
    expect(lessons.single.validFrom, '2026-11-02');
    expect(lessons.single.syncStatus, 'pending_create');
    final subjects = await (db.select(db.subjects)..where((t) => t.userId.equals('b'))).get();
    expect(subjects.single.title, 'Web');
    expect(lessons.single.subjectId, subjects.single.id);
  });

  test('import merges subjects with the same title', () async {
    await seed('a');
    final json = await exportScheduleJson(db, 'a');
    await importScheduleJson(db, 'a', json);
    final subjects = await (db.select(db.subjects)..where((t) => t.userId.equals('a'))).get();
    expect(subjects, hasLength(1));
  });

  test('invalid input throws FormatException', () async {
    expect(() => importScheduleJson(db, 'a', 'not json'), throwsFormatException);
    expect(() => importScheduleJson(db, 'a', '{"x": 1}'), throwsFormatException);
  });
}
