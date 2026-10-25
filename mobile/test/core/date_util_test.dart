import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/utils/date_util.dart';

void main() {
  group('academicWeekNumber', () {
    test('1 September of the academic year is week 1', () {
      expect(DateUtil.academicWeekNumber(DateTime(2026, 9, 1)), 1);
    });

    test('the rest of the first calendar week is still week 1', () {
      // 2026-09-01 is a Tuesday; Sunday 2026-09-06 closes week 1.
      expect(DateUtil.academicWeekNumber(DateTime(2026, 9, 6)), 1);
      expect(DateUtil.academicWeekNumber(DateTime(2026, 9, 7)), 2);
    });

    test('January–August counts from 1 September of the previous year', () {
      // Week of 2026-09-01 starts Monday 2026-08-31; 2027-02-03 is in the
      // week starting Monday 2027-02-01, 154 days (22 weeks) later.
      final week = DateUtil.academicWeekNumber(DateTime(2027, 2, 3));
      expect(week, greaterThan(0));
      expect(week, 23);
    });

    test('31 August belongs to the previous academic year', () {
      // 2026-08-31 counts from 2025-09-01 (a Monday): 364 days -> week 53.
      expect(DateUtil.academicWeekNumber(DateTime(2026, 8, 31)), 53);
    });

    test('explicit semesterStart counts from it', () {
      final start = DateTime(2027, 1, 12); // Tuesday
      expect(DateUtil.academicWeekNumber(DateTime(2027, 1, 12), semesterStart: start), 1);
      expect(DateUtil.academicWeekNumber(DateTime(2027, 1, 18), semesterStart: start), 2);
      expect(DateUtil.academicWeekNumber(DateTime(2027, 2, 3), semesterStart: start), 4);
    });

    test('time of day does not affect the week', () {
      expect(DateUtil.academicWeekNumber(DateTime(2026, 9, 6, 23, 59)), 1);
    });
  });

  group('isEvenWeek', () {
    test('parity follows academicWeekNumber', () {
      for (final d in [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 8),
        DateTime(2027, 2, 3),
        DateTime(2027, 5, 20),
      ]) {
        expect(DateUtil.isEvenWeek(d), DateUtil.academicWeekNumber(d).isEven, reason: '$d');
      }
      expect(DateUtil.isEvenWeek(DateTime(2026, 9, 1)), isFalse);
      expect(DateUtil.isEvenWeek(DateTime(2026, 9, 8)), isTrue);
      expect(DateUtil.isEvenWeek(DateTime(2027, 2, 3)), isFalse);
    });

    test('parity with explicit semesterStart', () {
      final start = DateTime(2027, 1, 12);
      expect(DateUtil.isEvenWeek(DateTime(2027, 1, 18), semesterStart: start), isTrue);
    });
  });
}
