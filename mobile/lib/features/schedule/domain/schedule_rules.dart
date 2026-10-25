import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/utils/date_util.dart';

/// `YYYY-MM-DD` of a calendar day, the format of `lessons.specific_date`,
/// `valid_from` and `valid_to`.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String _two(int v) => v.toString().padLeft(2, '0');

/// Midnight of [d] in local time.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week that contains [d].
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// `HH:mm` → minutes since midnight; unparsable values sort last.
int minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return 24 * 60;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return 24 * 60;
  return h * 60 + m;
}

/// Minutes since midnight → `HH:mm`.
String hhmm(int minutes) => '${_two(minutes ~/ 60 % 24)}:${_two(minutes % 60)}';

/// Whether a manual [lesson] takes place on [day].
///
/// A lesson with `specificDate` occurs only on that date. Otherwise it repeats
/// on its weekday, limited by week parity (`isEvenWeek`, null = every week)
/// and the optional `validFrom` / `validTo` range. Deleted and cancelled
/// lessons never occur.
bool lessonOccursOn(Lesson lesson, DateTime day, {DateTime? semesterStart}) {
  if (lesson.isDeleted || lesson.isCancelled) return false;
  final key = dateKey(day);
  final specific = lesson.specificDate;
  if (specific != null && specific.isNotEmpty) return specific == key;
  if (lesson.dayOfWeek != day.weekday) return false;
  final parity = lesson.isEvenWeek;
  if (parity != null &&
      DateUtil.isEvenWeek(day, semesterStart: semesterStart) != parity) {
    return false;
  }
  final from = lesson.validFrom;
  if (from != null && from.isNotEmpty && key.compareTo(from) < 0) return false;
  final to = lesson.validTo;
  if (to != null && to.isNotEmpty && key.compareTo(to) > 0) return false;
  return true;
}

/// One row of the day list: a manual lesson or an LMS class session.
class ScheduleEntry {
  final int startMinutes;
  final String start;

  /// Null for LMS sessions without a duration.
  final String? end;
  final String? subjectId;
  final Lesson? lesson;
  final LmsEvent? lmsEvent;

  const ScheduleEntry._({
    required this.startMinutes,
    required this.start,
    required this.end,
    this.subjectId,
    this.lesson,
    this.lmsEvent,
  });

  bool get isLms => lmsEvent != null;

  factory ScheduleEntry.lesson(Lesson l) => ScheduleEntry._(
        startMinutes: minutesOf(l.startTime),
        start: l.startTime,
        end: l.endTime,
        subjectId: l.subjectId,
        lesson: l,
      );

  factory ScheduleEntry.lms(LmsEvent e) {
    final startsAt = DateTime.fromMillisecondsSinceEpoch(e.startsAt.toInt());
    final startMin = startsAt.hour * 60 + startsAt.minute;
    final duration = e.durationMin;
    return ScheduleEntry._(
      startMinutes: startMin,
      start: hhmm(startMin),
      end: duration == null || duration <= 0 ? null : hhmm(startMin + duration),
      lmsEvent: e,
    );
  }
}

/// Manual lessons occurring on [day] plus LMS class sessions starting that
/// day, sorted by start time (manual first on ties).
List<ScheduleEntry> entriesForDay(
  DateTime day, {
  required List<Lesson> lessons,
  required List<LmsEvent> lmsClasses,
  DateTime? semesterStart,
}) {
  final start = dayOnly(day);
  final end = DateTime(start.year, start.month, start.day + 1);
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  final result = <ScheduleEntry>[
    for (final l in lessons)
      if (lessonOccursOn(l, start, semesterStart: semesterStart))
        ScheduleEntry.lesson(l),
    for (final e in lmsClasses)
      if (!e.isDeleted &&
          e.startsAt.toInt() >= startMs &&
          e.startsAt.toInt() < endMs)
        ScheduleEntry.lms(e),
  ];
  result.sort((a, b) {
    final c = a.startMinutes.compareTo(b.startMinutes);
    if (c != 0) return c;
    if (a.isLms == b.isLms) return 0;
    return a.isLms ? 1 : -1;
  });
  return result;
}
