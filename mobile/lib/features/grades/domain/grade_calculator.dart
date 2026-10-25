/// Pure grade maths. All thresholds come from `grading_rules.dart`.
///
/// Rounding rule: a course total is rounded to 1 decimal, half up
/// (49.95 -> 50.0, 49.94 -> 49.9). A tiny epsilon is added before rounding so
/// binary float noise (e.g. 49.9999999 or 49.95 stored as 49.94999...) cannot
/// flip the result. Letters, statuses, averages and scholarship all use this
/// rounded total, so what the user sees always matches the letter/status.
/// Admission rating and required final are not rounded; comparisons against
/// thresholds use the same epsilon.
library;

import 'grading_rules.dart';

/// Tolerance for float noise in comparisons and rounding.
const double _eps = 1e-9;

/// Scores of one course; null means "no grade yet" (never 0).
class CourseScores {
  final double? midterm;
  final double? endterm;
  final double? finalExam;
  final double? lmsTotal;
  final int credits;

  const CourseScores({
    this.midterm,
    this.endterm,
    this.finalExam,
    this.lmsTotal,
    this.credits = kDefaultCredits,
  });
}

/// Letter grade with GPA points.
class LetterGrade {
  final String letter;
  final double points;

  const LetterGrade(this.letter, this.points);

  @override
  bool operator ==(Object other) =>
      other is LetterGrade && other.letter == letter && other.points == points;

  @override
  int get hashCode => Object.hash(letter, points);

  @override
  String toString() => 'LetterGrade($letter, $points)';
}

enum CourseStatus { noGrades, inProgress, passed, atRisk, failed }

enum ScholarshipStatus { increased, regular, none, unknown }

/// Rounds to 1 decimal, half up, tolerant to float noise.
double _round1(double value) => ((value * 10) + _eps).roundToDouble() / 10;

bool _below(double value, double threshold) => value < threshold - _eps;

/// Mean of present midterm/endterm; null if both are absent.
double? admissionRating(CourseScores s) {
  final parts = [s.midterm, s.endterm].whereType<double>().toList();
  if (parts.isEmpty) return null;
  return parts.reduce((a, b) => a + b) / parts.length;
}

/// Weighted total when midterm, endterm and final are all present,
/// otherwise the LMS total; rounded to 1 decimal.
double? courseTotal(CourseScores s) {
  if (s.midterm != null && s.endterm != null && s.finalExam != null) {
    final admission = admissionRating(s)!;
    return _round1(kAdmissionWeight * admission + kFinalWeight * s.finalExam!);
  }
  final lms = s.lmsTotal;
  return lms == null ? null : _round1(lms);
}

/// Letter for a total; the total is rounded to 1 decimal first.
LetterGrade letterFor(double total) {
  final rounded = _round1(total);
  for (final (min, letter, points) in kLetterScale) {
    if (!_below(rounded, min)) return LetterGrade(letter, points);
  }
  return const LetterGrade(kFailLetter, kFailPoints);
}

/// Final exam score needed to reach [targetTotal]; null without admission.
/// May exceed [kMaxScore] (unreachable) or be negative (already reached).
double? requiredFinal(CourseScores s, double targetTotal) {
  final admission = admissionRating(s);
  if (admission == null) return null;
  return (targetTotal - kAdmissionWeight * admission) / kFinalWeight;
}

/// Course status. With a final present the result is passed or failed
/// (failed also when admission was below the threshold); without a final,
/// low admission, an unreachable pass, or an LMS-only total below the
/// threshold mean atRisk.
CourseStatus statusFor(CourseScores s) {
  if (s.midterm == null &&
      s.endterm == null &&
      s.finalExam == null &&
      s.lmsTotal == null) {
    return CourseStatus.noGrades;
  }

  final admission = admissionRating(s);
  final total = courseTotal(s);
  final finalExam = s.finalExam;

  if (finalExam != null) {
    if (_below(finalExam, kPassThreshold) ||
        (admission != null && _below(admission, kPassThreshold)) ||
        (total != null && _below(total, kPassThreshold))) {
      return CourseStatus.failed;
    }
    return total != null ? CourseStatus.passed : CourseStatus.inProgress;
  }

  if (admission != null) {
    final needed = requiredFinal(s, kPassThreshold)!;
    if (_below(admission, kPassThreshold) || needed > kMaxScore + _eps) {
      return CourseStatus.atRisk;
    }
    return CourseStatus.inProgress;
  }

  // Only the LMS total is known.
  return _below(total!, kPassThreshold)
      ? CourseStatus.atRisk
      : CourseStatus.passed;
}

/// Credit-weighted mean of a per-course value over courses with a total.
double? _weighted(
  Iterable<CourseScores> courses,
  double Function(double total) value,
) {
  var sum = 0.0;
  var credits = 0;
  for (final c in courses) {
    final total = courseTotal(c);
    if (total == null || c.credits <= 0) continue;
    sum += value(total) * c.credits;
    credits += c.credits;
  }
  return credits == 0 ? null : sum / credits;
}

/// Credit-weighted average total; courses without a total are ignored.
double? weightedAverage(Iterable<CourseScores> courses) =>
    _weighted(courses, (t) => t);

/// Credit-weighted GPA (4.00 scale); courses without a total are ignored.
double? gpa(Iterable<CourseScores> courses) =>
    _weighted(courses, (t) => letterFor(t).points);

/// Scholarship by the lowest known total; unknown if no totals.
ScholarshipStatus scholarshipFor(Iterable<CourseScores> courses) {
  final totals = courses.map(courseTotal).whereType<double>().toList();
  if (totals.isEmpty) return ScholarshipStatus.unknown;
  final lowest = totals.reduce((a, b) => a < b ? a : b);
  if (!_below(lowest, kIncreasedScholarship)) {
    return ScholarshipStatus.increased;
  }
  if (!_below(lowest, kRegularScholarship)) return ScholarshipStatus.regular;
  return ScholarshipStatus.none;
}
