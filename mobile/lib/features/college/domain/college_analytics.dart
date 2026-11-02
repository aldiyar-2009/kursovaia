/// College grade analytics over a SmartNation snapshot (100-point marks).
/// SmartNation has no credits or GPA letters: the figures are averages of
/// marks, their spread over months and absences.
library;

import 'package:studyplan/features/college/data/college_models.dart';

/// Thresholds used by SmartNation summaries (as on the portal and in the
/// server snapshot: «90+» excellent, below 50 a retake, below 70 at risk).
const double kCollegeExcellent = 90;
const double kCollegeAtRisk = 70;
const double kCollegeFail = 50;

/// Numeric marks of all subjects (absences and «зачёт»-like labels have no
/// value and are skipped).
Iterable<SnGrade> numericGrades(Iterable<SnSubject> subjects) =>
    subjects.expand((s) => s.grades).where((g) => g.value != null && !g.absent);

/// Average mark per calendar month, oldest first.
List<(DateTime month, double average, int count)> monthlyAverages(
  Iterable<SnSubject> subjects,
) {
  final sums = <DateTime, (double, int)>{};
  for (final g in numericGrades(subjects)) {
    final day = g.day;
    if (day == null) continue;
    final month = DateTime(day.year, day.month);
    final (sum, n) = sums[month] ?? (0.0, 0);
    sums[month] = (sum + g.value!, n + 1);
  }
  final months = sums.keys.toList()..sort();
  return [for (final m in months) (m, sums[m]!.$1 / sums[m]!.$2, sums[m]!.$2)];
}

/// Marks in four bands: 90–100, 70–89, 50–69, below 50.
class MarkBands {
  final int excellent;
  final int good;
  final int satisfactory;
  final int failing;

  const MarkBands(this.excellent, this.good, this.satisfactory, this.failing);

  int get total => excellent + good + satisfactory + failing;
}

MarkBands markBands(Iterable<SnSubject> subjects) {
  var a = 0, b = 0, c = 0, d = 0;
  for (final g in numericGrades(subjects)) {
    final v = g.value!;
    if (v >= kCollegeExcellent) {
      a++;
    } else if (v >= kCollegeAtRisk) {
      b++;
    } else if (v >= kCollegeFail) {
      c++;
    } else {
      d++;
    }
  }
  return MarkBands(a, b, c, d);
}

/// Subjects with an average, best first.
List<SnSubject> subjectsByAverage(Iterable<SnSubject> subjects) =>
    subjects.where((s) => s.average != null).toList()
      ..sort((x, y) => y.average!.compareTo(x.average!));

/// Subjects with absences, most first.
List<SnSubject> subjectsByAbsences(Iterable<SnSubject> subjects) =>
    subjects.where((s) => s.absences > 0).toList()
      ..sort((x, y) => y.absences.compareTo(x.absences));

/// Change of the monthly average between the last two months with marks;
/// null with fewer than two months.
double? lastMonthTrend(Iterable<SnSubject> subjects) {
  final months = monthlyAverages(subjects);
  if (months.length < 2) return null;
  return months.last.$2 - months[months.length - 2].$2;
}

/// Average of the last [count] numeric marks of [subject] (recent form).
double? recentAverage(SnSubject subject, {int count = 5}) {
  final marks =
      subject.grades.where((g) => g.value != null && !g.absent).toList()
        ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
  if (marks.isEmpty) return null;
  final tail = marks.length <= count
      ? marks
      : marks.sublist(marks.length - count);
  return tail.map((g) => g.value!).reduce((a, b) => a + b) / tail.length;
}
