import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/services/ics_export_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2026, 10, 26, 12); // Monday

  test('no lessons -> calendar without events', () async {
    final ics = await IcsExportService.generateScheduleIcs(db, 'u1', now: now);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, isNot(contains('BEGIN:VEVENT')));
  });

  test('exports only the user\'s active lessons from drift', () async {
    final ts = BigInt.from(1);
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 's1',
          userId: 'u1',
          title: 'Calculus',
          teacherName: const Value('Teacher A'),
          updatedAt: ts,
        ));
    Future<void> lesson(String id, String userId, {bool deleted = false}) =>
        db.into(db.lessons).insert(LessonsCompanion.insert(
              id: id,
              subjectId: 's1',
              userId: userId,
              dayOfWeek: 3,
              startTime: '10:00',
              endTime: '11:20',
              classroom: const Value('C1.2.204'),
              isDeleted: Value(deleted),
              updatedAt: ts,
            ));
    await lesson('l1', 'u1');
    await lesson('l2', 'u1', deleted: true);
    await lesson('l3', 'u2');

    final ics = await IcsExportService.generateScheduleIcs(db, 'u1', now: now);
    expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
    expect(ics, contains('UID:l1@studyplan'));
    expect(ics, contains('SUMMARY:Calculus'));
    expect(ics, contains('DESCRIPTION:Teacher A'));
    expect(ics, contains('LOCATION:C1.2.204'));
    expect(ics, contains('DTSTART;TZID=Asia/Almaty:20261028T100000'));
    expect(ics, contains('RRULE:FREQ=WEEKLY;UNTIL=20270630T185959Z'));
  });
}
