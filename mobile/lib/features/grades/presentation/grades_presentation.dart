import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Glue between drift rows, the grade calculator and the UI.
/// No thresholds here: every rule comes from `grade_calculator.dart`.

/// Scores of a stored course; the stored `total` acts as the LMS total.
CourseScores scoresOf(LmsCourse c) => CourseScores(
      midterm: c.registerMidterm,
      endterm: c.registerEndterm,
      finalExam: c.finalExam,
      lmsTotal: c.total,
      credits: c.credits,
    );

/// Max content width of grades screens on wide windows.
const double kGradesMaxWidth = 720;

/// Current semester =everything not explicitly past (inprogress, future,
/// or a manual course without classification).
bool isCurrentCourse(LmsCourse c) => c.classification != 'past';

bool isManualCourse(LmsCourse c) => c.source == 'manual';

/// Scores and averages are shown with one decimal and a dot, like the LMS.
String formatScore(double value) => value.toStringAsFixed(1);

String formatGpa(double value) => value.toStringAsFixed(2);

/// Parses a user-entered score; accepts both "85,5" and "85.5".
double? parseScore(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String formatDateTime(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  try {
    return DateFormat.yMMMd(locale).add_Hm().format(value);
  } catch (_) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }
}

/// Label and tone for a course status; null for [CourseStatus.noGrades]
/// (the row then shows «нет оценки» instead of a total).
(String, StatusTone)? courseStatusLabel(
  AppLocalizations l10n,
  CourseStatus status,
) {
  return switch (status) {
    CourseStatus.noGrades => null,
    CourseStatus.inProgress => (l10n.grades_statusInProgress, StatusTone.neutral),
    CourseStatus.passed => (l10n.grades_statusPassed, StatusTone.success),
    CourseStatus.atRisk => (l10n.grades_statusAtRisk, StatusTone.warning),
    CourseStatus.failed => (l10n.grades_statusFailed, StatusTone.danger),
  };
}

(String, StatusTone) scholarshipLabel(
  AppLocalizations l10n,
  ScholarshipStatus status,
) {
  return switch (status) {
    ScholarshipStatus.increased =>
      (l10n.grades_scholarshipIncreased, StatusTone.success),
    ScholarshipStatus.regular =>
      (l10n.grades_scholarshipRegular, StatusTone.success),
    ScholarshipStatus.none => (l10n.grades_scholarshipNone, StatusTone.warning),
    ScholarshipStatus.unknown =>
      (l10n.grades_scholarshipUnknown, StatusTone.neutral),
  };
}
