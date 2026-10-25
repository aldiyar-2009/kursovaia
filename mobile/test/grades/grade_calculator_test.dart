import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';

CourseScores _total(double? total, [int credits = 5]) =>
    CourseScores(lmsTotal: total, credits: credits);

void main() {
  group('admissionRating', () {
    test('mean of midterm and endterm', () {
      expect(
        admissionRating(const CourseScores(midterm: 80, endterm: 90)),
        closeTo(85, 1e-9),
      );
    });

    test('uses the only present component', () {
      expect(admissionRating(const CourseScores(midterm: 70)), 70);
    });

    test('null when both absent', () {
      expect(admissionRating(const CourseScores(lmsTotal: 80)), isNull);
    });
  });

  group('courseTotal', () {
    test('mid 80, end 90, final 70 -> 79.0', () {
      expect(
        courseTotal(
          const CourseScores(midterm: 80, endterm: 90, finalExam: 70),
        ),
        79.0,
      );
    });

    test('falls back to lmsTotal when components incomplete', () {
      expect(
        courseTotal(const CourseScores(midterm: 80, lmsTotal: 66.6)),
        66.6,
      );
    });

    test('null when nothing usable', () {
      expect(courseTotal(const CourseScores(midterm: 80)), isNull);
      expect(courseTotal(const CourseScores()), isNull);
    });

    test('rounds to 1 decimal, half up (49.95 -> 50.0)', () {
      expect(courseTotal(_total(49.95)), 50.0);
      expect(courseTotal(_total(49.94)), 49.9);
    });

    test('float noise at boundary resolves to 50.0', () {
      // 0.6 * 50 + 0.4 * 50 may be 49.999999... in binary.
      expect(
        courseTotal(
          const CourseScores(midterm: 50, endterm: 50, finalExam: 50),
        ),
        50.0,
      );
    });
  });

  group('letterFor', () {
    test('50 -> D', () {
      final g = letterFor(50);
      expect(g.letter, 'D');
      expect(g.points, 1.0);
    });

    test('49.9 -> F', () {
      final g = letterFor(49.9);
      expect(g.letter, 'F');
      expect(g.points, 0);
    });

    test('94.9 -> A-', () => expect(letterFor(94.9).letter, 'A-'));
    test('95 -> A', () => expect(letterFor(95).letter, 'A'));
    test('100 -> A', () => expect(letterFor(100).letter, 'A'));
    test('84.9 -> B', () => expect(letterFor(84.9).letter, 'B'));
    test('0 -> F', () => expect(letterFor(0).letter, 'F'));
    test(
      '49.95 rounds to 50.0 -> D',
      () => expect(letterFor(49.95).letter, 'D'),
    );
  });

  group('statusFor', () {
    test('all null -> noGrades', () {
      expect(statusFor(const CourseScores()), CourseStatus.noGrades);
    });

    test('mid 40, end 59.8 (admission 49.9) -> atRisk', () {
      expect(
        statusFor(const CourseScores(midterm: 40, endterm: 59.8)),
        CourseStatus.atRisk,
      );
    });

    test('lmsTotal 50 -> passed', () {
      expect(statusFor(_total(50)), CourseStatus.passed);
    });

    test('lmsTotal 49.9 only -> atRisk', () {
      expect(statusFor(_total(49.9)), CourseStatus.atRisk);
    });

    test('total exactly 50 with final -> passed', () {
      expect(
        statusFor(const CourseScores(midterm: 50, endterm: 50, finalExam: 50)),
        CourseStatus.passed,
      );
    });

    test('final below 50 -> failed even if total >= 50', () {
      expect(
        statusFor(
          const CourseScores(midterm: 100, endterm: 100, finalExam: 40),
        ),
        CourseStatus.failed,
      );
    });

    test('total below 50 with final -> failed', () {
      expect(
        statusFor(const CourseScores(midterm: 50, endterm: 50, finalExam: 30)),
        CourseStatus.failed,
      );
    });

    test('admission ok, final pending -> inProgress', () {
      expect(
        statusFor(const CourseScores(midterm: 70, endterm: 80)),
        CourseStatus.inProgress,
      );
    });

    test('admission exactly 50 -> not atRisk', () {
      expect(
        statusFor(const CourseScores(midterm: 50, endterm: 50)),
        CourseStatus.inProgress,
      );
    });
  });

  group('requiredFinal', () {
    test('mid 80, end 90, target 90 -> 97.5', () {
      expect(
        requiredFinal(const CourseScores(midterm: 80, endterm: 90), 90),
        closeTo(97.5, 1e-9),
      );
    });

    test('null without admission', () {
      expect(requiredFinal(_total(80), 50), isNull);
    });
  });

  group('weightedAverage', () {
    test('[(90,5),(60,10)] -> 70.0', () {
      expect(
        weightedAverage([_total(90, 5), _total(60, 10)]),
        closeTo(70.0, 1e-9),
      );
    });

    test('nulls ignored', () {
      expect(
        weightedAverage([
          _total(90, 5),
          const CourseScores(credits: 10),
          _total(60, 10),
          const CourseScores(midterm: 30, credits: 5),
        ]),
        closeTo(70.0, 1e-9),
      );
    });

    test('null when no totals', () {
      expect(weightedAverage([const CourseScores()]), isNull);
      expect(weightedAverage(const []), isNull);
    });
  });

  group('gpa', () {
    test('[(95,5),(85,5)] -> 3.665', () {
      expect(gpa([_total(95), _total(85)]), closeTo(3.665, 0.001));
    });

    test('nulls ignored', () {
      expect(
        gpa([_total(95), const CourseScores(), _total(85)]),
        closeTo(3.665, 0.001),
      );
    });

    test('null when no totals', () {
      expect(gpa([const CourseScores()]), isNull);
    });
  });

  group('scholarshipFor', () {
    test('all >= 90 -> increased', () {
      expect(
        scholarshipFor([_total(90), _total(97), const CourseScores()]),
        ScholarshipStatus.increased,
      );
    });

    test('all >= 75 -> regular', () {
      expect(
        scholarshipFor([_total(95), _total(75)]),
        ScholarshipStatus.regular,
      );
    });

    test('any below 75 -> none', () {
      expect(
        scholarshipFor([_total(95), _total(74.9)]),
        ScholarshipStatus.none,
      );
    });

    test('no totals -> unknown', () {
      expect(
        scholarshipFor([const CourseScores(midterm: 90)]),
        ScholarshipStatus.unknown,
      );
      expect(scholarshipFor(const []), ScholarshipStatus.unknown);
    });
  });
}
