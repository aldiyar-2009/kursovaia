/// Pure parsers for Moodle 4.x HTML pages of lms.astanait.edu.kz.
///
/// This is the fallback path of the LMS import: used when the page AJAX
/// (`/lib/ajax/service.php`) refuses a function. Covered by tests on
/// anonymized real pages in `test/lms/fixtures/`.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'lms_models.dart';

final _numberRe = RegExp(r'-?\d+(?:[.,]\d+)?');

/// Parses a grade as Moodle prints it: `"85,50"` → 85.5, `"85.5 %"` → 85.5,
/// `"-"`, `"–"`, `""` → null (no grade).
///
/// `"0,00"` is 0.0 only when the course has graded items; pass
/// [hasGradedItems] `false` when it is known that nothing is graded yet, then
/// zero becomes null.
double? parseMoodleScore(String raw, {bool hasGradedItems = true}) {
  final text = raw.replaceAll(' ', ' ').trim();
  final match = _numberRe.firstMatch(text);
  if (match == null) return null;
  final value = double.tryParse(match.group(0)!.replaceAll(',', '.'));
  if (value == null) return null;
  if (value == 0 && !hasGradedItems) return null;
  return value;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _hiddenClasses = {
  'accesshide',
  'visually-hidden',
  'sr-only',
  'action-menu',
};

/// Visible text of [node]: skips screen-reader-only spans, collapses spaces.
String _visibleText(Node? node) {
  if (node == null) return '';
  final buf = StringBuffer();
  void walk(Node n) {
    if (n is Text) {
      buf.write(n.data);
    } else if (n is Element) {
      if (n.classes.any(_hiddenClasses.contains)) return;
      if (n.localName == 'script' || n.localName == 'style') return;
      n.nodes.forEach(walk);
    }
  }

  walk(node);
  return buf
      .toString()
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Element? _ancestor(Element e, bool Function(Element) test) {
  Element? p = e.parent;
  while (p != null) {
    if (test(p)) return p;
    p = p.parent;
  }
  return null;
}

int? _queryInt(String? href, String name) {
  if (href == null) return null;
  final m = RegExp('[?&]$name=(\\d+)').firstMatch(href);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Splits Moodle's `"Course title | Teacher name"` course label.
(String, String?) _splitCourseLabel(String label) {
  final i = label.indexOf(' | ');
  if (i < 0) return (label.trim(), null);
  final teacher = label.substring(i + 3).trim();
  return (label.substring(0, i).trim(), teacher.isEmpty ? null : teacher);
}

// ---------------------------------------------------------------------------
// Grades
// ---------------------------------------------------------------------------

/// Parses `/grade/report/overview/index.php` (table `#overview-grade`).
///
/// Each course row links to `course/user.php?mode=grade&id=N`; the label is
/// split on `" | "` into title and teacher; empty filler rows are skipped.
///
/// Rule «нет оценки» (Review Focus 1): the overview shows `0,00` both for a
/// real zero and for a course where nothing is graded yet (semester start).
/// When every course in the overview is `0,00` / empty, all totals are treated
/// as unknown (`null`); a per-course report ([applyCourseGradeReport]) may fill
/// them later. If at least one course has a non-zero grade, the values are
/// taken as printed.
List<LmsCourseData> parseGradesOverview(String html) {
  final doc = html_parser.parse(html);
  final courses = <LmsCourseData>[];
  final seen = <int>{};
  for (final a in doc.querySelectorAll('a[href*="course/user.php"]')) {
    final href = a.attributes['href'] ?? '';
    if (!href.contains('mode=grade')) continue;
    final id = _queryInt(href, 'id');
    if (id == null || !seen.add(id)) continue;
    final label = _visibleText(a);
    if (label.isEmpty) continue;
    final (title, teacher) = _splitCourseLabel(label);
    final row = _ancestor(a, (e) => e.localName == 'tr');
    String gradeText = '';
    if (row != null) {
      final cells = row.querySelectorAll('td');
      final gradeCell =
          row.querySelector('td.c1') ?? (cells.length > 1 ? cells.last : null);
      gradeText = _visibleText(gradeCell);
    }
    courses.add(
      LmsCourseData(
        lmsCourseId: id,
        title: title,
        teacherName: teacher,
        total: parseMoodleScore(gradeText),
      ),
    );
  }
  final anyNonZero = courses.any((c) => c.total != null && c.total != 0);
  if (anyNonZero) return courses;
  return [
    for (final c in courses)
      LmsCourseData(
        lmsCourseId: c.lmsCourseId,
        title: c.title,
        teacherName: c.teacherName,
        classification: c.classification,
      ),
  ];
}

final _courseTotalRe = RegExp(
  r'course total|итоговая оценка за курс|итог за курс|курс бойынша қорытынды',
  caseSensitive: false,
);

/// Parses the user grade report of one course
/// (`/course/user.php?mode=grade&id=N`, table `.user-grade`) and fills
/// midterm / endterm / final / total and `gradeItemsJson` on [base].
/// Name matching and the «нет оценки» rule: see [applyGradeItemList].
/// Returns [base] unchanged when the page has no grade table.
LmsCourseData applyCourseGradeReport(LmsCourseData base, String html) {
  final doc = html_parser.parse(html);
  final items = <LmsGradeItem>[];
  double? courseTotal;
  for (final row in doc.querySelectorAll('tr')) {
    final nameCell = row.querySelector('.column-itemname');
    final gradeCell = row.querySelector('td.column-grade');
    if (nameCell == null || gradeCell == null) continue; // headers, categories
    final header = nameCell.querySelector('.gradeitemheader');
    final name = _visibleText(header ?? nameCell);
    if (name.isEmpty) continue;
    final grade = parseMoodleScore(_visibleText(gradeCell));
    final isCourseTotal =
        nameCell.classes.contains('courseitem') ||
        row.classes.contains('courseitem') ||
        _courseTotalRe.hasMatch(name);
    if (isCourseTotal) {
      courseTotal = grade;
      continue;
    }
    final range = _visibleText(row.querySelector('td.column-range'));
    items.add(
      LmsGradeItem(
        name: name,
        grade: grade,
        range: range.isEmpty ? null : range,
      ),
    );
  }
  return applyGradeItemList(base, items, courseTotal: courseTotal);
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

/// Parses `/user/profile.php`: full name from the page heading, e-mail from the
/// (entity-obfuscated) `mailto:` link, LMS user id from profile links.
LmsProfileData parseProfile(String html) {
  final doc = html_parser.parse(html);
  var name = _visibleText(
    doc.querySelector('.page-header-headings h1') ??
        doc.querySelector('.page-context-header h1') ??
        doc.querySelector('h1'),
  );
  if (name.isEmpty) {
    final title = _visibleText(doc.querySelector('title'));
    final i = title.indexOf(':');
    name = i > 0 ? title.substring(0, i).trim() : title;
  }

  String? email;
  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href']!.trim();
    if (!href.toLowerCase().startsWith('mailto:')) continue;
    final text = _visibleText(a);
    email = text.contains('@') ? text : Uri.decodeComponent(href.substring(7));
    break;
  }

  int? userId;
  final hrefs = doc
      .querySelectorAll('a[href]')
      .map((a) => a.attributes['href']!)
      .toList();
  for (final pattern in [
    RegExp(r'user/edit\.php\?id=(\d+)'),
    RegExp(r'user/profile\.php\?id=(\d+)'),
    RegExp(r'user/view\.php\?id=(\d+)'),
  ]) {
    for (final h in hrefs) {
      final m = pattern.firstMatch(h);
      if (m != null) {
        userId = int.tryParse(m.group(1)!);
        break;
      }
    }
    if (userId != null) break;
  }

  return LmsProfileData(fullName: name, email: email, lmsUserId: userId);
}

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

/// Events of [day] from a calendar page.
///
/// * Day view (`/calendar/view.php?view=day`, event cards
///   `[data-type="event"]`): every card belongs to [day]; start and end times
///   are the first two `HH:MM` of the «Когда» line, location from the row with
///   the map-marker icon, course from the `course/view.php?id=` link.
/// * Month view (`/calendar/view.php?view=month`): events of the cell
///   `td[data-region="day"][data-day=…]`; the month view prints no times, so
///   `startsAt` is midnight of [day] and `durationMin` is null. A month page of
///   another month gives an empty list.
List<LmsEventData> parseCalendarDay(String html, DateTime day) {
  final doc = html_parser.parse(html);
  final cards = doc.querySelectorAll('[data-type="event"]');
  if (cards.isNotEmpty) {
    return [for (final c in cards) ?_parseEventCard(c, day)];
  }
  final (year, month) = _monthOf(doc);
  if (year != day.year || month != day.month) return [];
  for (final cell in doc.querySelectorAll('td[data-region="day"]')) {
    if (cell.attributes['data-day'] == '${day.day}') {
      return _monthCellEvents(cell, DateTime(day.year, day.month, day.day));
    }
  }
  return [];
}

/// All events of a month view page (`/calendar/view.php?view=month`), each at
/// midnight of its day (the month view has no times).
List<LmsEventData> parseCalendarMonth(String html) {
  final doc = html_parser.parse(html);
  final (year, month) = _monthOf(doc);
  if (year == null || month == null) return [];
  final events = <LmsEventData>[];
  for (final cell in doc.querySelectorAll('td[data-region="day"]')) {
    final d = int.tryParse(cell.attributes['data-day'] ?? '');
    if (d == null) continue;
    events.addAll(_monthCellEvents(cell, DateTime(year, month, d)));
  }
  return events;
}

(int?, int?) _monthOf(Document doc) {
  final w =
      doc.querySelector('.calendarwrapper[data-year][data-month]') ??
      doc.querySelector('[data-view="month"][data-year][data-month]');
  if (w == null) return (null, null);
  return (
    int.tryParse(w.attributes['data-year']!),
    int.tryParse(w.attributes['data-month']!),
  );
}

List<LmsEventData> _monthCellEvents(Element cell, DateTime date) {
  final events = <LmsEventData>[];
  for (final li in cell.querySelectorAll('li[data-region="event-item"]')) {
    final link = li.querySelector('a[data-event-id]') ?? li.querySelector('a');
    final title = _visibleText(li.querySelector('.eventname') ?? link);
    if (title.isEmpty) continue;
    final component = li.attributes['data-event-component'];
    events.add(
      LmsEventData(
        lmsEventId: int.tryParse(link?.attributes['data-event-id'] ?? ''),
        title: title,
        type: classifyMoodleEvent(
          moduleName: component,
          eventType: li.attributes['data-event-eventtype'],
        ),
        moduleName: _moduleName(component),
        startsAt: date,
        url: _realHref(link),
      ),
    );
  }
  return events;
}

final _timeRe = RegExp(r'\b(\d{1,2}):(\d{2})\b');

LmsEventData? _parseEventCard(Element card, DateTime day) {
  final title = _visibleText(card.querySelector('.name')).isNotEmpty
      ? _visibleText(card.querySelector('.name'))
      : (card.attributes['data-event-title'] ?? '').trim();
  if (title.isEmpty) return null;
  final component = card.attributes['data-event-component'];

  DateTime startsAt = DateTime(day.year, day.month, day.day);
  int? durationMin;
  String? location;
  final rows = card.querySelectorAll('.description .row');
  if (rows.isNotEmpty) {
    final times = _timeRe.allMatches(_visibleText(rows.first)).toList();
    if (times.isNotEmpty) {
      int minutes(RegExpMatch m) =>
          int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      final start = minutes(times[0]);
      startsAt = startsAt.add(Duration(minutes: start));
      if (times.length > 1 && minutes(times[1]) > start) {
        durationMin = minutes(times[1]) - start;
      }
    }
  }
  for (final row in rows) {
    final icon = row.querySelector('.col-1 i, .col-1 img, .col-1 .icon');
    final hint =
        '${icon?.className ?? ''} ${icon?.attributes['title'] ?? ''} '
                '${icon?.attributes['alt'] ?? ''}'
            .toLowerCase();
    if (hint.contains('map-marker') ||
        hint.contains('location') ||
        hint.contains('место') ||
        hint.contains('орны')) {
      final text = _visibleText(row.querySelector('.col-11') ?? row);
      if (text.isNotEmpty) location = text;
    }
  }

  final courseLink = card.querySelector('a[href*="course/view.php"]');
  final courseId =
      _queryInt(courseLink?.attributes['href'], 'id') ??
      int.tryParse(card.attributes['data-course-id'] ?? '');
  final courseTitle = courseLink == null
      ? null
      : _splitCourseLabel(_visibleText(courseLink)).$1;
  final url =
      _realHref(card.querySelector('a.card-link')) ??
      _realHref(card.querySelector('a[href*="/mod/"]'));

  return LmsEventData(
    lmsEventId: int.tryParse(card.attributes['data-event-id'] ?? ''),
    lmsCourseId: courseId,
    title: title,
    courseTitle: courseTitle,
    type: classifyMoodleEvent(
      moduleName: component,
      eventType: card.attributes['data-event-eventtype'],
    ),
    moduleName: _moduleName(component),
    startsAt: startsAt,
    durationMin: durationMin,
    location: location,
    url: url,
  );
}

String? _moduleName(String? component) {
  if (component == null || component.isEmpty) return null;
  return component.startsWith('mod_') ? component.substring(4) : component;
}

String? _realHref(Element? a) {
  final href = a?.attributes['href']?.trim();
  if (href == null || href.isEmpty || href == '#') return null;
  return href;
}

// ---------------------------------------------------------------------------
// Course contents
// ---------------------------------------------------------------------------

/// Maps a Moodle module name to the stored material type.
String moodleMaterialType(String? modname) => switch (modname) {
  'resource' => 'file',
  'folder' => 'folder',
  'url' => 'url',
  'page' => 'page',
  _ => 'other',
};

/// Parses a course page (`/course/view.php?id=N`): every activity
/// (`li.activity`, id from `data-id` / `module-N`, type from `modtype_X`) with
/// its section title. Labels (inline text, no link) are skipped.
List<LmsMaterialData> parseCourseContents(
  String html,
  int courseId,
  String courseTitle,
) {
  final doc = html_parser.parse(html);
  final result = <LmsMaterialData>[];
  for (final li in doc.querySelectorAll('li.activity')) {
    final modname = li.classes
        .firstWhere((c) => c.startsWith('modtype_'), orElse: () => '')
        .replaceFirst('modtype_', '');
    if (modname == 'label') continue;
    final title = _visibleText(li.querySelector('.instancename'));
    if (title.isEmpty) continue;
    final idText =
        li.attributes['data-id'] ??
        (li.id.startsWith('module-') ? li.id.substring(7) : '');
    final section = _ancestor(
      li,
      (e) =>
          e.localName == 'li' &&
          (e.classes.contains('section') ||
              e.attributes['data-for'] == 'section'),
    );
    final sectionTitle = _visibleText(section?.querySelector('.sectionname'));
    result.add(
      LmsMaterialData(
        lmsModuleId: int.tryParse(idText),
        lmsCourseId: courseId,
        courseTitle: courseTitle,
        sectionTitle: sectionTitle.isEmpty ? null : sectionTitle,
        title: title,
        materialType: moodleMaterialType(modname.isEmpty ? null : modname),
        url:
            _realHref(li.querySelector('a.aalink')) ??
            _realHref(li.querySelector('a[href*="/mod/"]')),
      ),
    );
  }
  return result;
}
