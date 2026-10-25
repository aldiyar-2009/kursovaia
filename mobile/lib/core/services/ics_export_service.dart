import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/utils/date_util.dart';

/// Builds an iCalendar (.ics) file from the user's own lessons.
class IcsExportService {
  /// Reads the user's lessons (and their subjects) from the local drift
  /// database and returns them as an iCalendar document. Deleted and
  /// cancelled lessons are skipped. Returns a calendar with no events when the
  /// user has no lessons.
  static Future<String> generateScheduleIcs(
    AppDatabase db,
    String userId, {
    String calendarName = 'StudyPlan',
    DateTime? now,
  }) async {
    final subjects = await (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .get();
    final subjectsById = {for (final s in subjects) s.id: s};

    final lessons = await (db.select(db.lessons)
          ..where((t) =>
              t.userId.equals(userId) &
              t.isDeleted.equals(false) &
              t.isCancelled.equals(false)))
        .get();
    lessons.sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      return byDay != 0 ? byDay : a.startTime.compareTo(b.startTime);
    });

    final rows = <Map<String, dynamic>>[
      for (final l in lessons)
        {
          'uid': l.id,
          'title': subjectsById[l.subjectId]?.title ?? l.topic,
          'teacher': subjectsById[l.subjectId]?.teacherName,
          'classroom': l.classroom,
          'startTime': l.startTime,
          'endTime': l.endTime,
          'dayOfWeek': l.dayOfWeek,
          'isEvenWeek': l.isEvenWeek,
          'specificDate': l.specificDate,
          'validFrom': l.validFrom,
          'validTo': l.validTo,
        },
    ];

    return generateUniversityCalendarIcs(groupName: calendarName, lessons: rows, now: now);
  }

  /// Formats already prepared lesson rows as an iCalendar document.
  ///
  /// Row keys: `title`, `startTime`, `endTime` (HH:mm), `dayOfWeek` (1 = Mon),
  /// optional `uid`, `classroom`, `teacher`, `isEvenWeek` (null = every week),
  /// `specificDate` (YYYY-MM-DD, one-off lesson), `validFrom`, `validTo`.
  /// Missing optional values are omitted from the event, never invented.
  static String generateUniversityCalendarIcs({
    required String groupName,
    required List<Map<String, dynamic>> lessons,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final buffer = StringBuffer();
    void line(String s) => buffer.write('$s\r\n');

    line('BEGIN:VCALENDAR');
    line('VERSION:2.0');
    line('PRODID:-//StudyPlan//Schedule//RU');
    line('CALSCALE:GREGORIAN');
    line('METHOD:PUBLISH');
    line('X-WR-CALNAME:${_escape(groupName)}');
    line('X-WR-TIMEZONE:Asia/Almaty');

    final dtStamp = _formatUtcDate(current.toUtc());
    final today = DateTime(current.year, current.month, current.day);

    for (var i = 0; i < lessons.length; i++) {
      final lesson = lessons[i];
      final title = (lesson['title'] as String?)?.trim();
      final startTime = lesson['startTime'] as String?;
      final endTime = lesson['endTime'] as String?;
      if (startTime == null || endTime == null) continue;

      final specificDate = _parseDate(lesson['specificDate'] as String?);
      final validFrom = _parseDate(lesson['validFrom'] as String?);
      final validTo = _parseDate(lesson['validTo'] as String?);
      final isEvenWeek = lesson['isEvenWeek'] as bool?;

      DateTime firstDay;
      String? rrule;
      if (specificDate != null) {
        firstDay = specificDate;
      } else {
        final dayOfWeek = (lesson['dayOfWeek'] as int?) ?? 1;
        var from = today;
        if (validFrom != null && validFrom.isAfter(from)) from = validFrom;
        firstDay = DateTime(from.year, from.month, from.day + (dayOfWeek - from.weekday + 7) % 7);
        if (isEvenWeek != null && DateUtil.isEvenWeek(firstDay) != isEvenWeek) {
          firstDay = DateTime(firstDay.year, firstDay.month, firstDay.day + 7);
        }
        final until = validTo ?? _academicYearEnd(today);
        if (firstDay.isAfter(until)) continue;
        final interval = isEvenWeek == null ? '' : ';INTERVAL=2';
        // UNTIL must be UTC when DTSTART has a TZID: 18:59:59Z = 23:59:59 in Almaty (UTC+5).
        rrule = 'RRULE:FREQ=WEEKLY$interval;UNTIL=${_formatDate(until)}T185959Z';
      }

      final start = _atTime(firstDay, startTime);
      final end = _atTime(firstDay, endTime);
      final classroom = (lesson['classroom'] as String?)?.trim();
      final teacher = (lesson['teacher'] as String?)?.trim();
      final uid = lesson['uid'] ?? 'lesson-$i';

      line('BEGIN:VEVENT');
      line('UID:$uid@studyplan');
      line('DTSTAMP:$dtStamp');
      line('SUMMARY:${_escape(title == null || title.isEmpty ? 'Занятие' : title)}');
      if (teacher != null && teacher.isNotEmpty) {
        line('DESCRIPTION:${_escape(teacher)}');
      }
      if (classroom != null && classroom.isNotEmpty) {
        line('LOCATION:${_escape(classroom)}');
      }
      line('DTSTART;TZID=Asia/Almaty:${_formatLocalDateTime(start)}');
      line('DTEND;TZID=Asia/Almaty:${_formatLocalDateTime(end)}');
      if (rrule != null) line(rrule);
      line('BEGIN:VALARM');
      line('TRIGGER:-PT15M');
      line('ACTION:DISPLAY');
      line('DESCRIPTION:${_escape(title == null || title.isEmpty ? 'Занятие' : title)}');
      line('END:VALARM');
      line('END:VEVENT');
    }

    line('END:VCALENDAR');
    return buffer.toString();
  }

  /// 30 June that closes the academic year containing [date].
  static DateTime _academicYearEnd(DateTime date) =>
      DateTime(date.month >= 7 ? date.year + 1 : date.year, 6, 30);

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _atTime(DateTime day, String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n');

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}${_two(dt.month)}${_two(dt.day)}';

  static String _formatUtcDate(DateTime dt) =>
      '${_formatDate(dt)}T${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}Z';

  static String _formatLocalDateTime(DateTime dt) =>
      '${_formatDate(dt)}T${_two(dt.hour)}${_two(dt.minute)}00';
}
