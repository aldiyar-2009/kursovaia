import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/lms/data/lms_models.dart';
import 'package:studyplan/features/lms/data/moodle_html_parser.dart';

String fixture(String name) =>
    File('test/lms/fixtures/$name').readAsStringSync();

/// Hand-written Moodle 4.x user grade report (grade/report/user, embedded in
/// course/user.php?mode=grade) with the markup the parser relies on.
const _userReportHtml = '''
<div role="main">
<table class="boxaligncenter generaltable user-grade" id="user-grade">
<thead><tr>
<th class="header column-itemname">Элемент оценивания</th>
<th class="header column-grade">Оценка</th>
<th class="header column-range">Диапазон</th>
</tr></thead>
<tbody>
<tr><th class="level1 levelodd b1b b1t column-itemname" colspan="3">
  <span class="gradeitemheader">Calculus 1</span></th></tr>
<tr>
  <th class="level2 leveleven item b1b column-itemname">
    <div class="rowtitle"><a class="gradeitemheader" href="#">Register Midterm</a></div>
  </th>
  <td class="level2 leveleven item b1b itemcenter column-grade">80,00</td>
  <td class="level2 leveleven item b1b itemcenter column-range">0&ndash;100</td>
</tr>
<tr>
  <th class="level2 leveleven item b1b column-itemname">
    <span class="gradeitemheader">Midterm exam</span>
  </th>
  <td class="level2 leveleven item b1b itemcenter column-grade">70,00</td>
  <td class="level2 leveleven item b1b itemcenter column-range">0&ndash;100</td>
</tr>
<tr>
  <th class="level2 leveleven item b1b column-itemname">
    <span class="gradeitemheader">Register Endterm</span>
  </th>
  <td class="level2 leveleven item b1b itemcenter column-grade">90,00</td>
  <td class="level2 leveleven item b1b itemcenter column-range">0&ndash;100</td>
</tr>
<tr>
  <th class="level2 leveleven item b1b column-itemname">
    <span class="gradeitemheader">Final exam</span>
  </th>
  <td class="level2 leveleven item b1b itemcenter column-grade">-</td>
  <td class="level2 leveleven item b1b itemcenter column-range">0&ndash;100</td>
</tr>
<tr>
  <th class="level1 levelodd courseitem b1b column-itemname">
    <span class="gradeitemheader">Итоговая оценка за курс</span>
  </th>
  <td class="level1 levelodd courseitem b1b itemcenter column-grade">51,00</td>
  <td class="level1 levelodd courseitem b1b itemcenter column-range">0&ndash;100</td>
</tr>
</tbody>
</table>
</div>
''';

/// Hand-written Moodle 4.x course page (course/view.php) fragment.
const _courseViewHtml = '''
<div role="main">
<ul class="topics">
<li id="section-0" class="section course-section main" data-for="section" data-sectionid="0">
  <h3 class="sectionname"><a href="#">General</a></h3>
  <ul class="section m-0 p-0 img-text">
    <li class="activity activity-wrapper resource modtype_resource" id="module-501" data-for="cmitem" data-id="501">
      <a class="aalink stretched-link" href="https://lms.astanait.edu.kz/mod/resource/view.php?id=501">
        <span class="instancename">Syllabus <span class="accesshide "> Файл</span></span></a>
    </li>
    <li class="activity label modtype_label" id="module-502" data-for="cmitem" data-id="502">
      <div class="contentwithoutlink">Welcome!</div>
    </li>
  </ul>
</li>
<li id="section-1" class="section course-section main" data-for="section" data-sectionid="1">
  <h3 class="sectionname"><a href="#">Week 1</a></h3>
  <ul class="section m-0 p-0 img-text">
    <li class="activity folder modtype_folder" id="module-503" data-for="cmitem" data-id="503">
      <a class="aalink" href="https://lms.astanait.edu.kz/mod/folder/view.php?id=503">
        <span class="instancename">Lecture slides <span class="accesshide "> Папка</span></span></a>
    </li>
    <li class="activity url modtype_url" id="module-504" data-for="cmitem" data-id="504">
      <a class="aalink" href="https://lms.astanait.edu.kz/mod/url/view.php?id=504">
        <span class="instancename">Video</span></a>
    </li>
    <li class="activity page modtype_page" id="module-505" data-for="cmitem" data-id="505">
      <a class="aalink" href="https://lms.astanait.edu.kz/mod/page/view.php?id=505">
        <span class="instancename">Reading</span></a>
    </li>
    <li class="activity assign modtype_assign" id="module-506" data-for="cmitem" data-id="506">
      <a class="aalink" href="https://lms.astanait.edu.kz/mod/assign/view.php?id=506">
        <span class="instancename">Homework 1</span></a>
    </li>
  </ul>
</li>
</ul>
</div>
''';

/// Hand-written Moodle 4.x day view (calendar/view.php?view=day) fragment.
const _dayViewHtml = '''
<div role="main">
<div class="eventlist my-1">
  <div data-type="event" data-course-id="2543" data-event-id="900001" class="event mt-3"
       data-event-title="Attendance (Group BDA-2608)" data-event-eventtype="attendance"
       data-event-component="mod_attendance">
    <div class="card rounded">
      <div class="box card-header clearfix calendar_event_course">
        <h3 class="name d-inline-block">Attendance (Group BDA-2608)</h3>
      </div>
      <div class="description card-body">
        <div class="row"><div class="col-1"><i class="icon fa fa-clock-o fa-fw" title="Когда"></i></div>
          <div class="col-11"><a href="#">Четверг, 1 октября</a>, 09:00 &raquo; 10:50</div></div>
        <div class="row mt-1"><div class="col-1"><i class="icon fa fa-map-marker fa-fw" title="Место"></i></div>
          <div class="col-11">C1.3.240</div></div>
        <div class="row mt-1"><div class="col-1"><i class="icon fa fa-graduation-cap fa-fw" title="Событие курса"></i></div>
          <div class="col-11"><a href="https://lms.astanait.edu.kz/course/view.php?id=2543">Calculus 1 | Teacher F</a></div></div>
      </div>
      <div class="card-footer text-end bg-transparent">
        <a href="https://lms.astanait.edu.kz/mod/attendance/view.php?id=76199" class="card-link">Перейти к элементу курса</a>
      </div>
    </div>
  </div>
  <div data-type="event" data-course-id="2614" data-event-id="900002" class="event mt-3"
       data-event-title="Lab 2 is due" data-event-eventtype="due" data-event-component="mod_assign">
    <div class="card rounded">
      <div class="box card-header clearfix calendar_event_course">
        <h3 class="name d-inline-block">Lab 2 is due</h3>
      </div>
      <div class="description card-body">
        <div class="row"><div class="col-1"><i class="icon fa fa-clock-o fa-fw" title="Когда"></i></div>
          <div class="col-11"><a href="#">Четверг, 1 октября</a>, 23:59</div></div>
        <div class="row mt-1"><div class="col-1"><i class="icon fa fa-graduation-cap fa-fw" title="Событие курса"></i></div>
          <div class="col-11"><a href="https://lms.astanait.edu.kz/course/view.php?id=2614">Introduction to Programming | Teacher D</a></div></div>
      </div>
      <div class="card-footer text-end bg-transparent">
        <a href="https://lms.astanait.edu.kz/mod/assign/view.php?id=86000" class="card-link">Перейти к элементу курса</a>
      </div>
    </div>
  </div>
</div>
</div>
''';

void main() {
  group('parseMoodleScore', () {
    final cases = <String, double?>{
      '85,50': 85.5,
      '85.5 %': 85.5,
      '85,5 %': 85.5,
      '100,00': 100.0,
      '0,00': 0.0,
      ' 72 ': 72.0,
      '-': null,
      '': null,
      '–': null,
      '—': null,
      'abc': null,
    };
    cases.forEach((raw, expected) {
      test('"$raw" -> $expected', () {
        expect(parseMoodleScore(raw), expected);
      });
    });

    test('"0,00" without graded items is null', () {
      expect(parseMoodleScore('0,00', hasGradedItems: false), isNull);
      expect(parseMoodleScore('85,00', hasGradedItems: false), 85.0);
    });
  });

  group('parseGradesOverview', () {
    test(
      'real overview fixture: 6 courses, all-zero totals are "no grade"',
      () {
        final courses = parseGradesOverview(fixture('grades_overview.html'));
        expect(courses, hasLength(6));
        expect(courses.first.lmsCourseId, 2752);
        expect(courses.first.title, 'Physical Education (Athletics)');
        expect(courses.first.teacherName, 'Teacher A');
        expect(courses.map((c) => c.lmsCourseId), [
          2752,
          2687,
          2675,
          2614,
          2544,
          2543,
        ]);
        expect(courses[5].title, 'Calculus 1');
        expect(courses[5].teacherName, 'Teacher F');
        // Review Focus 1: never 0 for a course without grades.
        expect(courses.every((c) => c.total == null), isTrue);
      },
    );

    test('keeps real totals when at least one course has a non-zero grade', () {
      const html = '''
<table id="overview-grade"><tbody>
<tr><td class="cell c0"><a href="https://lms.example/course/user.php?mode=grade&amp;id=10&amp;user=1">Math | T1</a></td><td class="cell c1">85,50</td></tr>
<tr><td class="cell c0"><a href="https://lms.example/course/user.php?mode=grade&amp;id=11&amp;user=1">Physics</a></td><td class="cell c1">-</td></tr>
<tr class="emptyrow"><td class="cell c0"></td><td class="cell c1"></td></tr>
</tbody></table>''';
      final courses = parseGradesOverview(html);
      expect(courses, hasLength(2));
      expect(courses[0].total, 85.5);
      expect(courses[0].teacherName, 'T1');
      expect(courses[1].title, 'Physics');
      expect(courses[1].teacherName, isNull);
      expect(courses[1].total, isNull);
    });

    test('empty or unrelated html gives an empty list', () {
      expect(parseGradesOverview(''), isEmpty);
      expect(parseGradesOverview('<html><body>Login</body></html>'), isEmpty);
    });
  });

  group('applyCourseGradeReport', () {
    const base = LmsCourseData(lmsCourseId: 2543, title: 'Calculus 1');

    test('fills midterm/endterm/final, total and grade items', () {
      final c = applyCourseGradeReport(base, _userReportHtml);
      expect(c.lmsCourseId, 2543);
      expect(c.title, 'Calculus 1');
      expect(c.midterm, 80.0); // "Register Midterm" wins over "Midterm exam"
      expect(c.endterm, 90.0);
      expect(c.finalExam, isNull);
      expect(c.total, 51.0);
      final items = (jsonDecode(c.gradeItemsJson!) as List)
          .cast<Map<String, dynamic>>();
      expect(items.map((i) => i['name']), [
        'Register Midterm',
        'Midterm exam',
        'Register Endterm',
        'Final exam',
      ]);
      expect(items.first['grade'], 80.0);
      expect(items.first['range'], '0–100');
      expect(items.last['grade'], isNull);
    });

    test('report without any graded item keeps total null', () {
      final html = _userReportHtml
          .replaceAll('80,00', '-')
          .replaceAll('70,00', '-')
          .replaceAll('90,00', '-')
          .replaceAll('51,00', '0,00');
      final c = applyCourseGradeReport(base, html);
      expect(c.midterm, isNull);
      expect(c.endterm, isNull);
      expect(c.total, isNull);
    });

    test('unparseable report returns the base unchanged', () {
      final c = applyCourseGradeReport(
        base.copyWith(total: 77.0),
        '<html>nothing</html>',
      );
      expect(c.total, 77.0);
      expect(c.gradeItemsJson, isNull);
    });
  });

  group('parseProfile', () {
    test('real profile fixture', () {
      final p = parseProfile(fixture('profile.html'));
      expect(p.fullName, 'Student Test');
      expect(p.email, 'student@example.com');
      expect(p.lmsUserId, 1);
    });
  });

  group('parseCalendarDay / parseCalendarMonth', () {
    test('month view fixture: events of 1 October 2026', () {
      final events = parseCalendarDay(
        fixture('calendar_month.html'),
        DateTime(2026, 10, 1),
      );
      expect(events, hasLength(6));
      final deadline = events.firstWhere(
        (e) => e.type == LmsEventType.deadline,
      );
      expect(deadline.lmsEventId, 304379);
      expect(deadline.title, 'Test 1 (Lek 1,2,3) is due');
      expect(deadline.moduleName, 'assign');
      expect(
        deadline.url,
        'https://lms.astanait.edu.kz/mod/assign/view.php?id=86947',
      );
      expect(deadline.startsAt, DateTime(2026, 10, 1));
      expect(
        events.where((e) => e.type == LmsEventType.classSession),
        hasLength(5),
      );
      expect(events.where((e) => e.moduleName == 'attendance'), hasLength(5));
    });

    test('month view fixture: a day from another month gives nothing', () {
      expect(
        parseCalendarDay(fixture('calendar_month.html'), DateTime(2026, 11, 1)),
        isEmpty,
      );
    });

    test('month view fixture: whole month', () {
      final events = parseCalendarMonth(fixture('calendar_month.html'));
      expect(events, hasLength(97));
      expect(
        events.where((e) => e.type == LmsEventType.classSession),
        hasLength(76),
      );
      // assign "due" (16) + quiz "close" (3) are deadlines; quiz "open" is other.
      expect(
        events.where((e) => e.type == LmsEventType.deadline),
        hasLength(19),
      );
      expect(events.where((e) => e.type == LmsEventType.other), hasLength(2));
      expect(
        events.every((e) => e.startsAt.year == 2026 && e.startsAt.month == 10),
        isTrue,
      );
    });

    test('day view: times, duration, location and course', () {
      final events = parseCalendarDay(_dayViewHtml, DateTime(2026, 10, 1));
      expect(events, hasLength(2));
      final cls = events[0];
      expect(cls.type, LmsEventType.classSession);
      expect(cls.lmsEventId, 900001);
      expect(cls.lmsCourseId, 2543);
      expect(cls.courseTitle, 'Calculus 1');
      expect(cls.startsAt, DateTime(2026, 10, 1, 9, 0));
      expect(cls.durationMin, 110);
      expect(cls.location, 'C1.3.240');
      expect(
        cls.url,
        'https://lms.astanait.edu.kz/mod/attendance/view.php?id=76199',
      );
      final due = events[1];
      expect(due.type, LmsEventType.deadline);
      expect(due.startsAt, DateTime(2026, 10, 1, 23, 59));
      expect(due.durationMin, isNull);
      expect(due.location, isNull);
      expect(due.moduleName, 'assign');
    });
  });

  group('parseCourseContents', () {
    test('lists files, folders, links, pages; skips labels', () {
      final m = parseCourseContents(_courseViewHtml, 2543, 'Calculus 1');
      expect(m.map((x) => x.title), [
        'Syllabus',
        'Lecture slides',
        'Video',
        'Reading',
        'Homework 1',
      ]);
      expect(m.map((x) => x.materialType), [
        'file',
        'folder',
        'url',
        'page',
        'other',
      ]);
      expect(m.first.lmsModuleId, 501);
      expect(m.first.lmsCourseId, 2543);
      expect(m.first.courseTitle, 'Calculus 1');
      expect(m.first.sectionTitle, 'General');
      expect(m[1].sectionTitle, 'Week 1');
      expect(
        m.first.url,
        'https://lms.astanait.edu.kz/mod/resource/view.php?id=501',
      );
    });
  });

  group('LmsEventType', () {
    test('storage values', () {
      expect(LmsEventType.deadline.storageValue, 'deadline');
      expect(LmsEventType.classSession.storageValue, 'class');
      expect(LmsEventType.other.storageValue, 'other');
      expect(LmsEventType.fromStorage('class'), LmsEventType.classSession);
      expect(LmsEventType.fromStorage('weird'), LmsEventType.other);
    });
  });
}
