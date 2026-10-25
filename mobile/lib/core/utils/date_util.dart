abstract final class DateUtil {
  static const _monthsRu = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ];

  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _daysOfWeekRu = [
    'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
  ];

  static const _daysOfWeekEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static String formatHeaderDate(DateTime date, {bool isRu = true}) {
    final day = date.day;
    final month = isRu ? _monthsRu[date.month - 1] : _monthsEn[date.month - 1];
    final dayOfWeek = isRu ? _daysOfWeekRu[date.weekday - 1] : _daysOfWeekEn[date.weekday - 1];
    return '$day $month • $dayOfWeek';
  }

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

  static String weekName(DateTime date, {DateTime? semesterStart, bool isRu = true}) {
    final even = isEvenWeek(date, semesterStart: semesterStart);
    if (isRu) {
      return even ? 'Четная неделя' : 'Нечетная неделя';
    } else {
      return even ? 'Even week' : 'Odd week';
    }
  }

  static String fullHeaderContext(DateTime date, {DateTime? semesterStart, bool isRu = true}) {
    return '${formatHeaderDate(date, isRu: isRu)} • ${weekName(date, semesterStart: semesterStart, isRu: isRu)}';
  }
}
