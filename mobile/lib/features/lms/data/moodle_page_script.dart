/// JavaScript run inside the logged-in LMS page (same origin, the browser
/// attaches the session cookies itself; the app never reads cookies).
///
/// Usage from the WebView (Task E2), with `flutter_inappwebview`:
/// ```dart
/// final r = await controller.callAsyncJavaScript(
///   functionBody: '$kMoodleImportScript\n$kMoodleImportInvocation',
///   arguments: {'sinceSec': since, 'untilSec': until},
/// );
/// buildImportResult(jsonDecode(r!.value as String));
/// ```
///
/// Output (a JSON string), every leaf being `{data: …}` or `{error: "…"}`:
/// ```
/// { ajax: { courses: {inprogress, past}, deadlines, calendar: [month…],
///           contents: {courseId: …}, gradeItems: {courseId: …} },
///   html: { overview, profile, calendar: [month…], contents: {courseId: …},
///           gradeReports: {courseId: …} } }
/// ```
/// HTML pages are fetched only as a fallback for a kind whose AJAX call
/// failed, except the grade overview and the profile (always fetched: the
/// profile has no AJAX source, the overview backs up per-course grades).
///
/// Each AJAX call is sent as its own one-element batch
/// (`[{index, methodname, args}]`): `lib/ajax/service.php` stops processing a
/// batch at the first failing call, which would lose the independent kinds.
library;

/// Body to append after [kMoodleImportScript] in `callAsyncJavaScript`.
const String kMoodleImportInvocation =
    'return await studyplanImport(sinceSec, untilSec);';

/// Defines `async function studyplanImport(sinceSec, untilSec)` → JSON string.
const String kMoodleImportScript = r'''
async function studyplanImport(sinceSec, untilSec) {
  var cfg = (typeof M !== 'undefined' && M.cfg) ? M.cfg : {};
  var root = (cfg.wwwroot || location.origin).replace(/\/$/, '');
  var sesskey = (typeof M !== 'undefined' && M.cfg) ? M.cfg.sesskey : null;

  function errText(e) {
    if (!e) return 'unknown error';
    if (typeof e === 'string') return e;
    return String(e.message || e.errorcode || e.error || e);
  }

  async function ajax(methodname, args) {
    if (!sesskey) return {error: 'no sesskey'};
    try {
      var res = await fetch(root + '/lib/ajax/service.php?sesskey=' + encodeURIComponent(sesskey) +
          '&info=' + encodeURIComponent(methodname), {
        method: 'POST',
        credentials: 'same-origin',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify([{index: 0, methodname: methodname, args: args}])
      });
      if (!res.ok) return {error: 'HTTP ' + res.status};
      var body = await res.json();
      if (!Array.isArray(body)) return {error: errText(body && (body.exception || body.error || 'bad response'))};
      var r = body[0];
      if (!r) return {error: 'empty response'};
      if (r.error) return {error: errText(r.exception)};
      return {data: r.data};
    } catch (e) {
      return {error: errText(e)};
    }
  }

  async function page(path) {
    try {
      var res = await fetch(root + path, {credentials: 'same-origin'});
      if (!res.ok) return {error: 'HTTP ' + res.status};
      if (/\/login\/index\.php/.test(res.url)) return {error: 'not logged in'};
      return {data: await res.text()};
    } catch (e) {
      return {error: errText(e)};
    }
  }

  async function pool(items, limit, fn) {
    var out = new Array(items.length);
    var next = 0;
    async function worker() {
      while (next < items.length) {
        var i = next++;
        out[i] = await fn(items[i], i);
      }
    }
    var workers = [];
    for (var w = 0; w < Math.min(limit, items.length); w++) workers.push(worker());
    await Promise.all(workers);
    return out;
  }

  function months() {
    var list = [];
    var d = new Date(sinceSec * 1000);
    var end = new Date(untilSec * 1000);
    var cur = new Date(d.getFullYear(), d.getMonth(), 1);
    while (cur <= end && list.length < 24) {
      list.push({year: cur.getFullYear(), month: cur.getMonth() + 1,
                 time: Math.floor(cur.getTime() / 1000)});
      cur = new Date(cur.getFullYear(), cur.getMonth() + 1, 1);
    }
    return list;
  }

  var out = {
    ajax: {courses: {}, deadlines: null, calendar: [], contents: {}, gradeItems: {}},
    html: {overview: null, profile: null, calendar: [], contents: {}, gradeReports: {}}
  };

  // Courses: core_course_get_enrolled_courses_by_timeline_classification.
  var classifications = ['inprogress', 'past'];
  var courseResults = await Promise.all(classifications.map(function (c) {
    return ajax('core_course_get_enrolled_courses_by_timeline_classification',
        {classification: c, limit: 0, offset: 0, sort: 'fullname'});
  }));
  var currentIds = [];
  var allIds = [];
  classifications.forEach(function (c, i) {
    out.ajax.courses[c] = courseResults[i];
    var list = (courseResults[i].data && courseResults[i].data.courses) || [];
    list.forEach(function (course) {
      if (allIds.indexOf(course.id) < 0) allIds.push(course.id);
      if (c === 'inprogress' && currentIds.indexOf(course.id) < 0) currentIds.push(course.id);
    });
  });

  // Always: grade overview + profile (HTML only).
  var pages = await Promise.all([page('/grade/report/overview/index.php'), page('/user/profile.php')]);
  out.html.overview = pages[0];
  out.html.profile = pages[1];
  if (allIds.length === 0 && pages[0].data) {
    var re = /course\/user\.php\?mode=grade&(?:amp;)?id=(\d+)/g;
    var m;
    while ((m = re.exec(pages[0].data)) !== null) {
      var id = parseInt(m[1], 10);
      if (allIds.indexOf(id) < 0) allIds.push(id);
    }
    currentIds = allIds.slice();
  }

  // Deadlines: core_calendar_get_action_events_by_timesort (paged by 50).
  var events = [];
  var after = 0;
  var deadlineError = null;
  for (var p = 0; p < 10; p++) {
    var args = {timesortfrom: sinceSec, timesortto: untilSec, limitnum: 50, limittononsuspendedevents: true};
    if (after) args.aftereventid = after;
    var r = await ajax('core_calendar_get_action_events_by_timesort', args);
    if (r.error) { deadlineError = r.error; break; }
    var batch = (r.data && r.data.events) || [];
    events = events.concat(batch);
    if (batch.length < 50 || !r.data.lastid) break;
    after = r.data.lastid;
  }
  out.ajax.deadlines = (deadlineError && events.length === 0)
      ? {error: deadlineError} : {data: {events: events}};

  // Classes: core_calendar_get_calendar_monthly_view per month.
  var monthList = months();
  out.ajax.calendar = await pool(monthList, 3, function (mo) {
    return ajax('core_calendar_get_calendar_monthly_view',
        {year: mo.year, month: mo.month, courseid: 1, categoryid: 0,
         includenavigation: false, mini: false, day: 1});
  });
  var calendarFailed = out.ajax.calendar.every(function (x) { return x.error; });
  if (calendarFailed || out.ajax.deadlines.error) {
    out.html.calendar = await pool(monthList, 3, function (mo) {
      return page('/calendar/view.php?view=month&time=' + mo.time);
    });
  }

  // Grade items per course: gradereport_user_get_grade_items, else HTML report.
  var gradeResults = await pool(allIds, 4, function (id) {
    return ajax('gradereport_user_get_grade_items', {courseid: id});
  });
  var failedGrades = [];
  allIds.forEach(function (id, i) {
    out.ajax.gradeItems[id] = gradeResults[i];
    if (gradeResults[i].error) failedGrades.push(id);
  });
  var reports = await pool(failedGrades, 4, function (id) {
    return page('/course/user.php?mode=grade&id=' + id);
  });
  failedGrades.forEach(function (id, i) { out.html.gradeReports[id] = reports[i]; });

  // Materials of current courses: core_course_get_contents, else course page.
  var contentResults = await pool(currentIds, 4, function (id) {
    return ajax('core_course_get_contents',
        {courseid: id, options: [{name: 'excludecontents', value: 'true'}]});
  });
  var failedContents = [];
  currentIds.forEach(function (id, i) {
    out.ajax.contents[id] = contentResults[i];
    if (contentResults[i].error) failedContents.push(id);
  });
  var coursePages = await pool(failedContents, 4, function (id) {
    return page('/course/view.php?id=' + id);
  });
  failedContents.forEach(function (id, i) { out.html.contents[id] = coursePages[i]; });

  return JSON.stringify(out);
}
''';
