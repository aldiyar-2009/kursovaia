import 'package:studyplan/l10n/generated/app_localizations.dart';

enum AcademicCategory { study, control, session, holidays, publicHoliday, practice }

/// Reference event of the 2026/2027 academic calendar (not user data).
class AcademicEvent {
  /// 1..12, selects the localized title and description.
  final int number;
  final AcademicCategory category;
  final DateTime start;

  /// Null for open-ended events ("с 6 июля").
  final DateTime? end;

  const AcademicEvent({
    required this.number,
    required this.category,
    required this.start,
    this.end,
  });

  /// True when [day] falls within the event (open-ended events last 60 days).
  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final last = end ?? DateTime(start.year, start.month, start.day + 60);
    return !d.isBefore(start) && !d.isAfter(last);
  }

  String title(AppLocalizations l10n) => switch (number) {
        1 => l10n.schedule_cal1Title,
        2 => l10n.schedule_cal2Title,
        3 => l10n.schedule_cal3Title,
        4 => l10n.schedule_cal4Title,
        5 => l10n.schedule_cal5Title,
        6 => l10n.schedule_cal6Title,
        7 => l10n.schedule_cal7Title,
        8 => l10n.schedule_cal8Title,
        9 => l10n.schedule_cal9Title,
        10 => l10n.schedule_cal10Title,
        11 => l10n.schedule_cal11Title,
        _ => l10n.schedule_cal12Title,
      };

  String description(AppLocalizations l10n) => switch (number) {
        1 => l10n.schedule_cal1Desc,
        2 => l10n.schedule_cal2Desc,
        3 => l10n.schedule_cal3Desc,
        4 => l10n.schedule_cal4Desc,
        5 => l10n.schedule_cal5Desc,
        6 => l10n.schedule_cal6Desc,
        7 => l10n.schedule_cal7Desc,
        8 => l10n.schedule_cal8Desc,
        9 => l10n.schedule_cal9Desc,
        10 => l10n.schedule_cal10Desc,
        11 => l10n.schedule_cal11Desc,
        _ => l10n.schedule_cal12Desc,
      };
}

String academicCategoryLabel(AcademicCategory c, AppLocalizations l10n) =>
    switch (c) {
      AcademicCategory.study => l10n.schedule_catStudy,
      AcademicCategory.control => l10n.schedule_catControl,
      AcademicCategory.session => l10n.schedule_catSession,
      AcademicCategory.holidays => l10n.schedule_catHolidays,
      AcademicCategory.publicHoliday => l10n.schedule_catPublicHoliday,
      AcademicCategory.practice => l10n.schedule_catPractice,
    };

/// AITU academic calendar 2026/2027.
final List<AcademicEvent> kAcademicEvents2026 = [
  AcademicEvent(number: 1, category: AcademicCategory.study, start: DateTime(2026, 9, 1), end: DateTime(2027, 2, 15)),
  AcademicEvent(number: 2, category: AcademicCategory.control, start: DateTime(2026, 11, 17), end: DateTime(2026, 11, 23)),
  AcademicEvent(number: 3, category: AcademicCategory.control, start: DateTime(2027, 2, 2), end: DateTime(2027, 2, 8)),
  AcademicEvent(number: 4, category: AcademicCategory.session, start: DateTime(2027, 2, 9), end: DateTime(2027, 2, 15)),
  AcademicEvent(number: 5, category: AcademicCategory.holidays, start: DateTime(2027, 2, 16), end: DateTime(2027, 2, 28)),
  AcademicEvent(number: 6, category: AcademicCategory.study, start: DateTime(2027, 3, 1), end: DateTime(2027, 6, 30)),
  AcademicEvent(number: 7, category: AcademicCategory.publicHoliday, start: DateTime(2027, 3, 21), end: DateTime(2027, 3, 25)),
  AcademicEvent(number: 8, category: AcademicCategory.control, start: DateTime(2027, 4, 13), end: DateTime(2027, 4, 19)),
  AcademicEvent(number: 9, category: AcademicCategory.control, start: DateTime(2027, 6, 1), end: DateTime(2027, 6, 7)),
  AcademicEvent(number: 10, category: AcademicCategory.session, start: DateTime(2027, 6, 8), end: DateTime(2027, 6, 20)),
  AcademicEvent(number: 11, category: AcademicCategory.practice, start: DateTime(2027, 6, 22), end: DateTime(2027, 7, 5)),
  AcademicEvent(number: 12, category: AcademicCategory.holidays, start: DateTime(2027, 7, 6)),
];
