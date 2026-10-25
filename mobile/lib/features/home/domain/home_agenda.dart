/// Pure logic behind the Home screen: what happens today, what is due soon,
/// which grades changed last. Works on drift rows only, never invents data.
library;

import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/utils/date_util.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';

/// How many days ahead the deadlines section looks (today included).
const int kHomeDeadlineDays = 7;

/// Maximum rows in the deadlines section.
const int kHomeDeadlineLimit = 5;

/// Maximum rows in the grades section.
const int kHomeGradeLimit = 3;

/// One lesson occurrence today, from the manual schedule or from LMS.
class AgendaLesson {
  final String title;
  final DateTime start;
  final DateTime end;
  final String? room;

  /// `lecture` / `practice` / `lab` for manual lessons, null for LMS.
  final String? lessonType;
  final bool fromLms;

  const AgendaLesson({
    required this.title,
    required this.start,
    required this.end,
    this.room,
    this.lessonType,
    this.fromLms = false,
  });

  bool isOngoing(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

enum DeadlineSource { own, group, lms }

/// A task or LMS deadline that is not done yet.
class AgendaDeadline {
  final String id;
  final String title;
  final String? subject;
  final DateTime due;
  final DeadlineSource source;

  const AgendaDeadline({
    required this.id,
    required this.title,
    required this.subject,
    required this.due,
    required this.source,
  });
}

/// A course with a computed total.
class AgendaGrade {
  final String id;
  final String title;
  final double total;
  final LetterGrade letter;
  final CourseStatus status;

  const AgendaGrade({
    required this.id,
    required this.title,
    required this.total,
    required this.letter,
    required this.status,
  });
}

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses `HH:mm` onto [day]; null when malformed.
DateTime? _at(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// Whether a manual lesson takes place on [day]: a one-off lesson on its
/// `specificDate`, otherwise a weekly one on its weekday, matching week
/// parity and within `validFrom..validTo`. Cancelled lessons never occur.
bool occursOn(Lesson l, DateTime day, {DateTime? semesterStart}) {
  if (l.isDeleted || l.isCancelled) return false;
  final iso = _isoDate(day);
  final specific = l.specificDate;
  if (specific != null && specific.isNotEmpty) return specific == iso;
  if (l.dayOfWeek != day.weekday) return false;
  final from = l.validFrom;
  if (from != null && from.isNotEmpty && iso.compareTo(from) < 0) return false;
  final to = l.validTo;
  if (to != null && to.isNotEmpty && iso.compareTo(to) > 0) return false;
  final parity = l.isEvenWeek;
  if (parity != null &&
      parity != DateUtil.isEvenWeek(day, semesterStart: semesterStart)) {
    return false;
  }
  return true;
}

/// All lessons of the day [now] falls on, sorted by start time.
List<AgendaLesson> lessonsForDay({
  required DateTime now,
  required List<Lesson> lessons,
  required List<Subject> subjects,
  required List<LmsEvent> lmsEvents,
  DateTime? semesterStart,
}) {
  final day = _dayStart(now);
  final titles = {for (final s in subjects) s.id: s.title};
  final result = <AgendaLesson>[];

  for (final l in lessons) {
    if (!occursOn(l, day, semesterStart: semesterStart)) continue;
    final start = _at(day, l.startTime);
    final end = _at(day, l.endTime);
    final title = titles[l.subjectId];
    if (start == null || end == null || title == null) continue;
    result.add(AgendaLesson(
      title: title,
      start: start,
      end: end.isAfter(start) ? end : start,
      room: l.classroom,
      lessonType: l.lessonType,
    ));
  }

  final nextDay = day.add(const Duration(days: 1));
  for (final e in lmsEvents) {
    if (e.isDeleted || e.eventType != 'class') continue;
    final start = DateTime.fromMillisecondsSinceEpoch(e.startsAt.toInt());
    if (start.isBefore(day) || !start.isBefore(nextDay)) continue;
    result.add(AgendaLesson(
      title: e.courseTitle?.isNotEmpty == true ? e.courseTitle! : e.title,
      start: start,
      end: start.add(Duration(minutes: e.durationMin ?? 0)),
      room: e.location,
      fromLms: true,
    ));
  }

  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

/// Lessons of today that have not ended yet: the first one is the current or
/// next lesson.
List<AgendaLesson> upcomingToday(DateTime now, List<AgendaLesson> today) =>
    today.where((l) => l.end.isAfter(now)).toList();

/// Not-completed own and group tasks plus not-done LMS deadlines due from
/// the start of today through the next [kHomeDeadlineDays] days, soonest
/// first, at most [kHomeDeadlineLimit].
List<AgendaDeadline> upcomingDeadlines({
  required DateTime now,
  required List<Task> tasks,
  required List<LmsEvent> lmsEvents,
}) {
  final from = _dayStart(now);
  final until = from.add(const Duration(days: kHomeDeadlineDays + 1));
  bool inWindow(DateTime d) => !d.isBefore(from) && d.isBefore(until);

  final items = <AgendaDeadline>[];
  for (final t in tasks) {
    final dueMs = t.dueDate;
    if (t.isDeleted || t.status == 'completed' || dueMs == null) continue;
    final due = DateTime.fromMillisecondsSinceEpoch(dueMs.toInt());
    if (!inWindow(due)) continue;
    items.add(AgendaDeadline(
      id: t.id,
      title: t.title,
      subject: t.subjectTitle,
      due: due,
      source: t.isGroup ? DeadlineSource.group : DeadlineSource.own,
    ));
  }
  for (final e in lmsEvents) {
    if (e.isDeleted || e.isDone || e.eventType != 'deadline') continue;
    final due = DateTime.fromMillisecondsSinceEpoch(e.startsAt.toInt());
    if (!inWindow(due)) continue;
    items.add(AgendaDeadline(
      id: e.id,
      title: e.title,
      subject: e.courseTitle,
      due: due,
      source: DeadlineSource.lms,
    ));
  }
  items.sort((a, b) => a.due.compareTo(b.due));
  return items.take(kHomeDeadlineLimit).toList();
}

/// Scores of a stored course for the grading domain.
CourseScores scoresOf(LmsCourse c) => CourseScores(
      midterm: c.registerMidterm,
      endterm: c.registerEndterm,
      finalExam: c.finalExam,
      lmsTotal: c.total,
      credits: c.credits,
    );

/// Up to [kHomeGradeLimit] courses with a total, most recently updated first.
List<AgendaGrade> recentGrades(List<LmsCourse> courses) {
  final withTotal = <(LmsCourse, double)>[];
  for (final c in courses) {
    if (c.isDeleted) continue;
    final total = courseTotal(scoresOf(c));
    if (total != null) withTotal.add((c, total));
  }
  withTotal.sort((a, b) => b.$1.updatedAt.compareTo(a.$1.updatedAt));
  return [
    for (final (c, total) in withTotal.take(kHomeGradeLimit))
      AgendaGrade(
        id: c.id,
        title: c.title,
        total: total,
        letter: letterFor(total),
        status: statusFor(scoresOf(c)),
      ),
  ];
}

/// Remaining first steps; empty when onboarding is over.
///
/// The checklist is shown while the schedule or the grades are still empty;
/// each satisfied item disappears. Once both exist, the group step is no
/// longer pushed here (it stays available under «Ещё»).
enum FirstStep { schedule, lms, group }

List<FirstStep> remainingFirstSteps({
  required bool hasLessons,
  required bool hasCourses,
  required bool hasGroup,
}) {
  if (hasLessons && hasCourses) return const [];
  return [
    if (!hasLessons) FirstStep.schedule,
    if (!hasCourses) FirstStep.lms,
    if (!hasGroup) FirstStep.group,
  ];
}
