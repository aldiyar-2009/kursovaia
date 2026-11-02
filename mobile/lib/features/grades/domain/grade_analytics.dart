/// University grade analytics over LMS / manual courses. Pure functions on
/// top of `grade_calculator.dart`; no thresholds of its own except the
/// targets taken from `grading_rules.dart`.
library;

import 'grade_calculator.dart';
import 'grading_rules.dart';

/// One course reduced to what the analytics needs.
class AnalyticsCourse {
  final String id;
  final String title;
  final CourseScores scores;

  const AnalyticsCourse({
    required this.id,
    required this.title,
    required this.scores,
  });

  double? get total => courseTotal(scores);
  CourseStatus get status => statusFor(scores);
}

/// Mean of the present values; null when there are none.
double? meanOf(Iterable<double?> values) {
  final present = values.whereType<double>().toList();
  if (present.isEmpty) return null;
  return present.reduce((a, b) => a + b) / present.length;
}

/// Average of each assessment component over the courses that have it.
class ComponentAverages {
  final double? midterm;
  final double? endterm;
  final double? finalExam;

  const ComponentAverages({this.midterm, this.endterm, this.finalExam});

  /// Endterm minus midterm: positive = the student improved after the
  /// midterm.
  double? get trend =>
      midterm == null || endterm == null ? null : endterm! - midterm!;
}

ComponentAverages componentAverages(Iterable<AnalyticsCourse> courses) =>
    ComponentAverages(
      midterm: meanOf(courses.map((c) => c.scores.midterm)),
      endterm: meanOf(courses.map((c) => c.scores.endterm)),
      finalExam: meanOf(courses.map((c) => c.scores.finalExam)),
    );

/// Number of courses per letter (only courses with a total), in the order of
/// [kLetterScale] followed by F; letters with zero courses are kept so the
/// chart has a stable axis.
List<(String, int)> letterDistribution(Iterable<AnalyticsCourse> courses) {
  final counts = <String, int>{
    for (final (_, letter, _) in kLetterScale) letter: 0,
    kFailLetter: 0,
  };
  for (final c in courses) {
    final total = c.total;
    if (total == null) continue;
    final letter = letterFor(total).letter;
    counts[letter] = (counts[letter] ?? 0) + 1;
  }
  return [for (final e in counts.entries) (e.key, e.value)];
}

/// Credits of all courses and of courses already passed.
class CreditSummary {
  final int total;
  final int passed;
  final int atRisk;

  const CreditSummary({
    required this.total,
    required this.passed,
    required this.atRisk,
  });
}

CreditSummary creditSummary(Iterable<AnalyticsCourse> courses) {
  var total = 0, passed = 0, atRisk = 0;
  for (final c in courses) {
    total += c.scores.credits;
    switch (c.status) {
      case CourseStatus.passed:
        passed += c.scores.credits;
      case CourseStatus.atRisk:
      case CourseStatus.failed:
        atRisk += c.scores.credits;
      case CourseStatus.noGrades:
      case CourseStatus.inProgress:
        break;
    }
  }
  return CreditSummary(total: total, passed: passed, atRisk: atRisk);
}

/// Courses with a total, best first.
List<AnalyticsCourse> rankedByTotal(Iterable<AnalyticsCourse> courses) =>
    courses.where((c) => c.total != null).toList()
      ..sort((a, b) => b.total!.compareTo(a.total!));

/// Courses that need attention (at risk or failed), worst first.
List<AnalyticsCourse> coursesNeedingAttention(
  Iterable<AnalyticsCourse> courses,
) {
  final list = courses
      .where(
        (c) =>
            c.status == CourseStatus.atRisk || c.status == CourseStatus.failed,
      )
      .toList();
  double key(AnalyticsCourse c) => c.total ?? admissionRating(c.scores) ?? 0;
  list.sort((a, b) => key(a).compareTo(key(b)));
  return list;
}

/// Final exam needed to reach each target total, for one course without a
/// final yet.
class FinalPlan {
  final AnalyticsCourse course;

  /// Target total → required final (may be above [kMaxScore] = unreachable,
  /// or ≤ 0 = already reached).
  final List<(double, double)> targets;

  const FinalPlan(this.course, this.targets);
}

/// Targets for the plan: pass, B (80) and A- (90). Taken from the letter
/// scale so they follow `grading_rules.dart`.
List<double> get finalPlanTargets {
  double minOf(String letter) =>
      kLetterScale.firstWhere((e) => e.$2 == letter).$1;
  return [kPassThreshold, minOf('B'), minOf('A-')];
}

List<FinalPlan> finalPlans(Iterable<AnalyticsCourse> courses) => [
  for (final c in courses)
    if (c.scores.finalExam == null && admissionRating(c.scores) != null)
      FinalPlan(c, [
        for (final t in finalPlanTargets) (t, requiredFinal(c.scores, t)!),
      ]),
];
