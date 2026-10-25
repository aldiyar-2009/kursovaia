import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Whole calendar days from [now] to [date] (negative in the past), ignoring
/// time of day and DST shifts.
int calendarDayDiff(DateTime date, DateTime now) {
  final a = DateTime.utc(now.year, now.month, now.day);
  final b = DateTime.utc(date.year, date.month, date.day);
  return b.difference(a).inDays;
}

/// Due moment for lists and rows, in the current locale:
///
/// * same day: «Сегодня, 20:00»; next day: «Завтра, 18:00»;
///   previous day: «Вчера, 18:00»;
/// * within 6 days either way: «чт, 29 окт.» (en «Thu, Oct 29»);
/// * later this year: «29 окт.»; another year: «29 окт. 2027 г.».
///
/// [withTime] appends «, 18:00» to the weekday and date forms too.
/// [now] defaults to `DateTime.now()`; pass it for a stable clock in tests.
String formatDue(
  BuildContext context,
  DateTime due, {
  DateTime? now,
  bool withTime = false,
}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final ref = now ?? DateTime.now();
  final time = DateFormat.Hm(locale).format(due);
  final days = calendarDayDiff(due, ref);

  switch (days) {
    case 0:
      return '${l10n.core_today}, $time';
    case 1:
      return '${l10n.core_tomorrow}, $time';
    case -1:
      return '${l10n.core_yesterday}, $time';
  }

  final String date;
  if (days.abs() <= 6) {
    date = DateFormat.MMMEd(locale).format(due);
  } else if (due.year == ref.year) {
    date = DateFormat.MMMd(locale).format(due);
  } else {
    date = DateFormat.yMMMd(locale).format(due);
  }
  return withTime ? '$date, $time' : date;
}
