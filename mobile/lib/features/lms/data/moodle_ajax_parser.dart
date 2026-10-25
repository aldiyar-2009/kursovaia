/// Pure parsers over the JSON returned by Moodle external functions called
/// through the page AJAX endpoint (`/lib/ajax/service.php`), plus
/// [buildImportResult], which combines them with the HTML fallback parsers.
///
/// Field names follow the Moodle return structures (moodledev.io, Moodle
/// 4.x `externallib` / exporters); every parser is defensive: unknown or
/// missing fields are skipped, nothing throws on malformed input.
library;

import 'package:html/parser.dart' as html_parser;

import 'lms_models.dart';
import 'moodle_html_parser.dart' as html;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

double? _double(Object? v) => v is num ? v.toDouble() : null;

/// Moodle formats names/locations with format_string (entities, sometimes
/// tags); this returns plain text.
String _plain(Object? v) {
  if (v == null) return '';
  final s = v.toString();
  if (!s.contains('<') && !s.contains('&')) return s.trim();
  return html_parser
      .parseFragment(s)
      .text!
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _nonEmpty(String s) => s.isEmpty ? null : s;

(String, String?) _splitCourseLabel(String label) {
  final i = label.indexOf(' | ');
  if (i < 0) return (label.trim(), null);
  final teacher = label.substring(i + 3).trim();
  return (label.substring(0, i).trim(), teacher.isEmpty ? null : teacher);
}

DateTime? _fromSec(Object? v) {
  final s = _int(v);
  return s == null ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
}

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ]
    : const [];

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

/// `core_course_get_enrolled_courses_by_timeline_classification` →
/// `{courses: [{id, fullname, shortname, …}], nextoffset}`. The full name on
/// lms.astanait.edu.kz is `"Title | Teacher"`.
List<LmsCourseData> parseEnrolledCourses(
  Object? json, {
  String? classification,
}) {
  final list = json is Map ? json['courses'] : json;
  final result = <LmsCourseData>[];
  for (final c in _maps(list)) {
    final id = _int(c['id']);
    final label = _plain(c['fullname'] ?? c['fullnamedisplay']);
    if (id == null || label.isEmpty) continue;
    final (title, teacher) = _splitCourseLabel(label);
    result.add(
      LmsCourseData(
        lmsCourseId: id,
        title: title,
        teacherName: teacher,
        classification: classification,
      ),
    );
  }
  return result;
}

LmsEventData? _event(
  Map<String, dynamic> e, {
  LmsEventType? forceType,
  bool useTimesort = false,
}) {
  final title = _plain(e['name']);
  final startsAt = _fromSec(
    useTimesort ? (e['timesort'] ?? e['timestart']) : e['timestart'],
  );
  if (title.isEmpty || startsAt == null) return null;
  final course = e['course'] is Map
      ? (e['course'] as Map).cast<String, dynamic>()
      : null;
  final courseLabel = _plain(course?['fullname']);
  final module = _plain(e['modulename']);
  final durationSec = _int(e['timeduration']) ?? 0;
  final url = _plain(e['url']).isNotEmpty
      ? _plain(e['url'])
      : _plain(e['viewurl']);
  return LmsEventData(
    lmsEventId: _int(e['id']),
    lmsCourseId: _int(course?['id']) ?? _int(e['courseid']),
    title: title,
    courseTitle: courseLabel.isEmpty ? null : _splitCourseLabel(courseLabel).$1,
    type:
        forceType ??
        classifyMoodleEvent(
          moduleName: module,
          eventType: _plain(e['eventtype']),
        ),
    moduleName: _nonEmpty(module),
    startsAt: startsAt,
    durationMin: durationSec > 0 ? (durationSec / 60).round() : null,
    location: _nonEmpty(_plain(e['location'])),
    url: _nonEmpty(url),
  );
}

/// `core_calendar_get_action_events_by_timesort` →
/// `{events: [event_exporter], firstid, lastid}`; every action event is a
/// deadline due at `timesort`.
List<LmsEventData> parseActionEvents(Object? json) {
  final list = json is Map ? json['events'] : json;
  return [
    for (final e in _maps(list))
      ?_event(e, forceType: LmsEventType.deadline, useTimesort: true),
  ];
}

/// Calendar views: `core_calendar_get_calendar_monthly_view`
/// (`weeks[].days[].events[]`) or `core_calendar_get_calendar_upcoming_view` /
/// `…_day_view` (`events[]`). Uses `timestart`, `timeduration` (seconds),
/// `location`; `modulename == 'attendance'` → class session. De-duplicated by
/// event id (multi-day events repeat in every day).
List<LmsEventData> parseCalendarView(Object? json) {
  if (json is! Map) return const [];
  final raw = <Map<String, dynamic>>[..._maps(json['events'])];
  for (final w in _maps(json['weeks'])) {
    for (final d in _maps(w['days'])) {
      raw.addAll(_maps(d['events']));
    }
  }
  final seen = <int>{};
  final result = <LmsEventData>[];
  for (final e in raw) {
    final ev = _event(e);
    if (ev == null) continue;
    if (ev.lmsEventId != null && !seen.add(ev.lmsEventId!)) continue;
    result.add(ev);
  }
  return result;
}

/// `core_course_get_contents` → `[{id, name, section, modules: [{id, name,
/// modname, url}]}]`. Material type: resource → file, folder, url, page, else
/// other; labels (no page of their own) are skipped.
List<LmsMaterialData> parseCourseContents(
  Object? json,
  int courseId,
  String courseTitle,
) {
  final result = <LmsMaterialData>[];
  for (final section in _maps(json)) {
    final sectionTitle = _plain(section['name']);
    for (final m in _maps(section['modules'])) {
      final modname = _plain(m['modname']);
      if (modname == 'label') continue;
      final title = _plain(m['name']);
      if (title.isEmpty) continue;
      result.add(
        LmsMaterialData(
          lmsModuleId: _int(m['id']),
          lmsCourseId: courseId,
          courseTitle: courseTitle,
          sectionTitle: _nonEmpty(sectionTitle),
          title: title,
          materialType: html.moodleMaterialType(modname),
          url: _nonEmpty(_plain(m['url'])),
        ),
      );
    }
  }
  return result;
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// `gradereport_user_get_grade_items` → `{usergrades: [{gradeitems: [{itemname,
/// itemtype, graderaw, gradeformatted, grademin, grademax, rangeformatted}]}]}`.
/// The `itemtype == 'course'` row is the course total; every other row is an
/// item. Same name matching and «нет оценки» rule as the HTML report
/// ([applyGradeItemList]).
///
/// Scores are stored as percent: `percentageformatted` when parseable, else
/// `graderaw` (or `gradeformatted`) scaled by `grademin`/`grademax`
/// ([gradeToPercent]); everything is clamped to 0..100.
LmsCourseData applyGradeItems(LmsCourseData base, Object? json) {
  if (json is! Map) return base;
  final users = _maps(json['usergrades']);
  if (users.isEmpty) return base;
  final items = <LmsGradeItem>[];
  double? courseTotal;
  for (final g in _maps(users.first['gradeitems'])) {
    final min = _double(g['grademin']);
    final max = _double(g['grademax']);
    final grade =
        html.parseMoodleScore(_plain(g['percentageformatted'])) ??
        gradeToPercent(
          _double(g['graderaw']) ??
              html.parseMoodleScore(_plain(g['gradeformatted'])),
          min: min,
          max: max,
        );
    if (g['itemtype'] == 'course') {
      courseTotal = grade;
      continue;
    }
    final name = _plain(g['itemname']);
    if (name.isEmpty) continue;
    var range = _plain(g['rangeformatted']);
    if (range.isEmpty && min != null && max != null) {
      range = '${_num(min)}–${_num(max)}';
    }
    items.add(LmsGradeItem(name: name, grade: grade, range: _nonEmpty(range)));
  }
  return applyGradeItemList(base, items, courseTotal: courseTotal);
}

// ---------------------------------------------------------------------------
// Result builder
// ---------------------------------------------------------------------------

/// Course classifications requested by `kMoodleImportScript`; each must load
/// (or be covered by the grade overview) for the course list to be complete.
const kRequiredCourseClassifications = ['inprogress', 'past'];

/// One `{data: …}` / `{error: "…"}` entry produced by `kMoodleImportScript`.
class _Entry {
  _Entry(Object? raw)
    : data = raw is Map ? raw['data'] : null,
      error = raw is Map
          ? (raw['error']?.toString() ??
                (raw.containsKey('data') ? null : 'missing'))
          : 'missing';

  final Object? data;
  final String? error;

  bool get ok => error == null && data != null;
  String? get text => ok && data is String ? data as String : null;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

List<_Entry> _entries(Object? v) =>
    v is List ? [for (final e in v) _Entry(e)] : const [];

/// First raw LMS error of [entries] (e.g. `HTTP 500`), or '' when none says
/// why. The UI names the failed kind itself (localized) and shows this only
/// as a detail, so no user-facing text is produced here.
String _firstError(Iterable<_Entry> entries) =>
    entries.map((e) => e.error).whereType<String>().firstOrNull ?? '';

/// Turns the JSON object returned by `studyplanImport()` (see
/// `moodle_page_script.dart`) into an [LmsImportResult].
///
/// Per kind it prefers AJAX data and falls back to the HTML parsers; a kind
/// that fails both ways gets a message in `errors` and the other kinds are
/// still filled. Never throws.
///
/// * `courses` — AJAX enrolled courses ([kRequiredCourseClassifications]).
///   When any of them failed, the grade overview page fills the gap (its
///   courses get the failed classification, `inprogress` when that one
///   failed); when the overview is unavailable too, the list is incomplete →
///   `errors['courses']` (the importer then deletes no course) and
///   `errors['materials']`.
/// * `grades` — per course: AJAX grade items, else the HTML course report,
///   else the overview total. Courses with neither report are listed in
///   `failedGradeCourseIds` (the importer keeps their stored scores).
///   `errors['grades']` only when no grade source worked at all.
/// * `deadlines` — AJAX action events, else deadlines of the HTML month pages.
/// * `classes` — attendance sessions of the AJAX monthly views, else of the
///   HTML month pages (no times there).
/// * `materials` — AJAX course contents, else the HTML course page; courses
///   that loaded go to `materialCourseIds`. Any course failing both ways, an
///   incomplete or empty course list → `errors['materials']`.
/// * `profile` — HTML profile page.
LmsImportResult buildImportResult(Map<String, dynamic> scriptOutput) {
  final errors = <String, String>{};
  final ajax = _map(scriptOutput['ajax']);
  final pages = _map(scriptOutput['html']);

  // ---- courses ----
  final courseEntries = _map(ajax['courses']);
  final courses = <int, LmsCourseData>{};
  final failedClasses = <String>[];
  for (final cls in kRequiredCourseClassifications) {
    final e = _Entry(courseEntries[cls]);
    if (!e.ok) {
      failedClasses.add(cls);
      continue;
    }
    for (final c in parseEnrolledCourses(e.data, classification: cls)) {
      courses.putIfAbsent(c.lmsCourseId, () => c);
    }
  }
  // Optional extra classification (not requested by the script today).
  final future = _Entry(courseEntries['future']);
  if (future.ok) {
    for (final c in parseEnrolledCourses(future.data, classification: 'future')) {
      courses.putIfAbsent(c.lmsCourseId, () => c);
    }
  }
  final overview = _Entry(pages['overview']);
  final overviewCourses = overview.text == null
      ? const <LmsCourseData>[]
      : html.parseGradesOverview(overview.text!);
  final overviewById = {for (final c in overviewCourses) c.lmsCourseId: c};
  var coursesComplete = true;
  if (failedClasses.isNotEmpty) {
    // The overview lists every enrolled course, so it covers any failed
    // classification. Courses it adds get the classification that failed:
    // when both failed (or only `inprogress`), they are current courses.
    final fillClass = failedClasses.contains('inprogress')
        ? 'inprogress'
        : failedClasses.first;
    if (overviewCourses.isEmpty) {
      coursesComplete = false;
    } else {
      for (final c in overviewCourses) {
        courses.putIfAbsent(
          c.lmsCourseId,
          () => c.classification == null
              ? c.copyWith(classification: fillClass)
              : c,
        );
      }
    }
  }
  if (!coursesComplete) {
    errors['courses'] = _firstError([
      for (final cls in failedClasses) _Entry(courseEntries[cls]),
      overview,
    ]);
  }

  // ---- grades ----
  final gradeItems = _map(ajax['gradeItems']);
  final gradeReports = _map(pages['gradeReports']);
  var anyGradeSource = overview.text != null;
  final gradeFailures = <_Entry>[overview];
  final failedGradeIds = <int>{};
  for (final id in courses.keys.toList()) {
    var c = courses[id]!;
    final fromOverview = overviewById[id];
    if (fromOverview != null && c.total == null && fromOverview.total != null) {
      c = c.copyWith(total: fromOverview.total);
    }
    final itemsEntry = _Entry(gradeItems['$id']);
    final reportEntry = _Entry(gradeReports['$id']);
    if (itemsEntry.ok) {
      c = applyGradeItems(c, itemsEntry.data);
      anyGradeSource = true;
    } else if (reportEntry.text != null) {
      c = html.applyCourseGradeReport(c, reportEntry.text!);
      anyGradeSource = true;
    } else {
      failedGradeIds.add(id);
      gradeFailures
        ..add(itemsEntry)
        ..add(reportEntry);
    }
    courses[id] = c;
  }
  if (!anyGradeSource) {
    errors['grades'] = _firstError(gradeFailures);
  }

  // ---- calendar ----
  final htmlMonths = _entries(pages['calendar']);
  List<LmsEventData>? htmlMonthEvents;
  List<LmsEventData> monthEventsFromHtml() => htmlMonthEvents ??= [
    for (final m in htmlMonths)
      if (m.text != null) ...html.parseCalendarMonth(m.text!),
  ];
  bool anyHtmlMonth() => htmlMonths.any((m) => m.text != null);

  final events = <LmsEventData>[];
  final deadlines = _Entry(ajax['deadlines']);
  if (deadlines.ok) {
    events.addAll(parseActionEvents(deadlines.data));
  } else if (anyHtmlMonth()) {
    events.addAll(
      monthEventsFromHtml().where((e) => e.type == LmsEventType.deadline),
    );
  } else {
    errors['deadlines'] = _firstError([
      deadlines,
      ...htmlMonths,
    ]);
  }

  final ajaxMonths = _entries(ajax['calendar']);
  final okMonths = ajaxMonths.where((m) => m.ok).toList();
  if (okMonths.isNotEmpty) {
    final seen = <int>{};
    for (final m in okMonths) {
      for (final e in parseCalendarView(m.data)) {
        if (e.type != LmsEventType.classSession) continue;
        if (e.lmsEventId != null && !seen.add(e.lmsEventId!)) continue;
        events.add(e);
      }
    }
  } else if (anyHtmlMonth()) {
    events.addAll(
      monthEventsFromHtml().where((e) => e.type == LmsEventType.classSession),
    );
  } else {
    errors['classes'] = _firstError([
      ...ajaxMonths,
      ...htmlMonths,
    ]);
  }

  // ---- materials ----
  final contents = _map(ajax['contents']);
  final contentPages = _map(pages['contents']);
  final materials = <LmsMaterialData>[];
  final materialCourseIds = <int>{};
  final failedCourses = <String>[];
  final materialFailures = <_Entry>[];
  for (final key in {...contents.keys, ...contentPages.keys}) {
    final id = int.tryParse(key);
    if (id == null) continue;
    final title = courses[id]?.title ?? '';
    final a = _Entry(contents[key]);
    final p = _Entry(contentPages[key]);
    if (a.ok) {
      materials.addAll(parseCourseContents(a.data, id, title));
      materialCourseIds.add(id);
    } else if (p.text != null) {
      materials.addAll(html.parseCourseContents(p.text!, id, title));
      materialCourseIds.add(id);
    } else {
      failedCourses.add(title.isEmpty ? key : title);
      materialFailures
        ..add(a)
        ..add(p);
    }
  }
  if (failedCourses.isNotEmpty) {
    final reason = _firstError(materialFailures);
    final courseList = failedCourses.join(', ');
    errors['materials'] = reason.isEmpty ? courseList : '$reason: $courseList';
  } else if (!coursesComplete || courses.isEmpty) {
    // Without a complete course list the set of courses whose materials were
    // requested is unknown: report it so the importer deletes nothing.
    errors['materials'] = errors['courses'] ?? '';
  }

  // ---- profile ----
  LmsProfileData? profile;
  final profilePage = _Entry(pages['profile']);
  if (profilePage.text != null) {
    final p = html.parseProfile(profilePage.text!);
    if (p.fullName.isNotEmpty) profile = p;
  }
  if (profile == null) {
    errors['profile'] = profilePage.error ?? '';
  }

  return LmsImportResult(
    courses: courses.values.toList(),
    events: events,
    materials: materials,
    profile: profile,
    errors: errors,
    failedGradeCourseIds: failedGradeIds,
    materialCourseIds: materialCourseIds,
  );
}
