/// Academic week arithmetic. Dates shown to the user are formatted with
/// `DateFormat(..., locale)` in the widgets, not here.
abstract final class DateUtil {
  /// Academic week number of [date] (week 1 = the Monday–Sunday week that
  /// contains the semester start).
  ///
  /// Without [semesterStart] the start is 1 September of the academic year
  /// containing [date]: the same calendar year for September–December and the
  /// previous one for January–August, so the result is positive for any date
  /// on or after that 1 September.
  static int academicWeekNumber(DateTime date, {DateTime? semesterStart}) {
    final start = semesterStart ??
        DateTime(date.month >= 9 ? date.year : date.year - 1, 9, 1);
    // Calendar-day arithmetic in UTC so DST shifts and time of day are ignored.
    final startMonday = DateTime.utc(start.year, start.month, start.day - (start.weekday - 1));
    final dateMonday = DateTime.utc(date.year, date.month, date.day - (date.weekday - 1));
    final diffDays = dateMonday.difference(startMonday).inDays;
    return (diffDays / 7).floor() + 1;
  }

  /// True when [date] falls in an even academic week (see [academicWeekNumber]).
  static bool isEvenWeek(DateTime date, {DateTime? semesterStart}) {
    return academicWeekNumber(date, semesterStart: semesterStart).isEven;
  }
}
