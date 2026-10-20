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

  static bool isEvenWeek(DateTime date, {DateTime? semesterStart}) {
    final start = semesterStart ?? DateTime(date.year, 9, 1);
    final startMonday = start.subtract(Duration(days: start.weekday - 1));
    final currentMonday = date.subtract(Duration(days: date.weekday - 1));
    final diffDays = currentMonday.difference(startMonday).inDays;
    final weekNumber = (diffDays / 7).floor() + 1;
    return weekNumber % 2 == 0;
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
