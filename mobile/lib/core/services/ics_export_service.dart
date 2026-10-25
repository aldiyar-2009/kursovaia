class IcsExportService {
  static String generateUniversityCalendarIcs({
    required String groupName,
    required List<Map<String, dynamic>> lessons,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Astana IT University//StudyPlan Schedule 2026-2027//RU');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:Расписание $groupName (Astana IT University)');
    buffer.writeln('X-WR-TIMEZONE:Asia/Almaty');

    final now = DateTime.now().toUtc();
    final dtStamp = _formatUtcDate(now);

    for (int i = 0; i < lessons.length; i++) {
      final lesson = lessons[i];
      final title = lesson['title'] ?? 'Занятие';
      final classroom = lesson['classroom'] ?? 'Аудитория AITU';
      final teacher = lesson['teacher'] ?? 'Преподаватель';
      final startTime = lesson['startTime'] ?? '08:30';
      final endTime = lesson['endTime'] ?? '09:50';
      final dayOfWeek = (lesson['dayOfWeek'] ?? 1) as int; // 1 = Monday

      // Create a recurring weekly event for semester
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:aitu-$groupName-$i@astanait.edu.kz');
      buffer.writeln('DTSTAMP:$dtStamp');
      buffer.writeln('SUMMARY:$title ($classroom)');
      buffer.writeln('DESCRIPTION:Преподаватель: $teacher\\nГруппа: $groupName\\nКабинет: $classroom');
      buffer.writeln('LOCATION:$classroom, Astana IT University');
      
      final eventStart = _getNextWeekdayTime(dayOfWeek, startTime);
      final eventEnd = _getNextWeekdayTime(dayOfWeek, endTime);
      buffer.writeln('DTSTART;TZID=Asia/Almaty:${_formatLocalDateTime(eventStart)}');
      buffer.writeln('DTEND;TZID=Asia/Almaty:${_formatLocalDateTime(eventEnd)}');
      buffer.writeln('RRULE:FREQ=WEEKLY;UNTIL=20270630T180000Z');
      buffer.writeln('BEGIN:VALARM');
      buffer.writeln('TRIGGER:-PT15M');
      buffer.writeln('ACTION:DISPLAY');
      buffer.writeln('DESCRIPTION:Напоминание о паре через 15 минут');
      buffer.writeln('END:VALARM');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static DateTime _getNextWeekdayTime(int dayOfWeek, String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    int daysToAdd = (dayOfWeek - now.weekday + 7) % 7;
    if (daysToAdd == 0) daysToAdd = 7;
    final targetDate = now.add(Duration(days: daysToAdd));
    return DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
  }

  static String _formatUtcDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }

  static String _formatLocalDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}00';
  }
}
