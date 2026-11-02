import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/grades/domain/grade_analytics.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';

AnalyticsCourse _c(
  String title, {
  double? mid,
  double? end,
  double? fin,
  int credits = 5,
}) =>
    AnalyticsCourse(
      id: title,
      title: title,
      scores: CourseScores(midterm: mid, endterm: end, finalExam: fin, credits: credits),
    );

void main() {
  final courses = [
    _c('Mobile', mid: 92, end: 88, fin: 95), // 0.6*90 + 0.4*95 = 92 -> A-
    _c('Databases', mid: 78, end: 84), // no final yet
    _c('History', mid: 40, end: 44, credits: 3), // admission < 50 -> at risk
    _c('English'), // no grades
  ];

  test('component averages use only courses that have the component', () {
    final avg = componentAverages(courses);
    expect(avg.midterm, closeTo((92 + 78 + 40) / 3, 1e-9));
    expect(avg.endterm, closeTo((88 + 84 + 44) / 3, 1e-9));
    expect(avg.finalExam, 95);
    expect(avg.trend, closeTo(avg.endterm! - avg.midterm!, 1e-9));
  });

  test('letter distribution counts only courses with a total', () {
    final letters = Map.fromEntries(
      letterDistribution(courses).map((e) => MapEntry(e.$1, e.$2)),
    );
    expect(letters['A-'], 1);
    expect(letters.values.reduce((a, b) => a + b), 1);
    expect(letters.containsKey('F'), isTrue);
  });

  test('credits: passed and at risk', () {
    final credits = creditSummary(courses);
    expect(credits.total, 18);
    expect(credits.passed, 5);
    expect(credits.atRisk, 3);
  });

  test('courses needing attention and ranking', () {
    expect(coursesNeedingAttention(courses).map((c) => c.title), ['History']);
    expect(rankedByTotal(courses).map((c) => c.title), ['Mobile']);
  });

  test('final plan lists required finals for 50 / 80 / 90', () {
    final plans = finalPlans(courses);
    expect(plans.map((p) => p.course.title), ['Databases', 'History']);
    final db = plans.first.targets;
    expect(db.map((t) => t.$1), [50, 80, 90]);
    // admission 81 -> (target - 0.6*81) / 0.4
    expect(db[1].$2, closeTo((80 - 0.6 * 81) / 0.4, 1e-9));
    expect(db[0].$2, lessThan(5)); // pass is almost reached
  });
}
