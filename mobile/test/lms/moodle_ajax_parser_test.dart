import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/lms/data/lms_models.dart';
import 'package:studyplan/features/lms/data/moodle_ajax_parser.dart';
import 'package:studyplan/features/lms/data/moodle_html_parser.dart'
    show applyCourseGradeReport;
import 'package:studyplan/features/lms/data/moodle_page_script.dart';

String fixture(String name) =>
    File('test/lms/fixtures/$name').readAsStringSync();

int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

// Samples follow the return structures of the Moodle external functions
// (course_summary_exporter, event_exporter_base, gradereport_user, core_course).

final _enrolled = {
  'courses': [
    {
      'id': 2543,
      'fullname': 'Calculus 1 | Teacher F',
      'shortname': 'CALC1',
      'viewurl': 'https://lms.astanait.edu.kz/course/view.php?id=2543',
      'hidden': false,
    },
    {
      'id': 2614,
      'fullname': 'Introduction to Programming &amp; Logic',
      'shortname': 'ITP',
    },
  ],
  'nextoffset': 2,
};

final _actionEvents = {
  'events': [
    {
      'id': 304379,
      'name': 'Test 1 (Lek 1,2,3) is due',
      'modulename': 'assign',
      'eventtype': 'due',
      'timestart': sec(DateTime(2026, 10, 1, 23, 59)),
      'timesort': sec(DateTime(2026, 10, 1, 23, 59)),
      'timeduration': 0,
      'course': {'id': 2543, 'fullname': 'Calculus 1 | Teacher F'},
      'url': 'https://lms.astanait.edu.kz/mod/assign/view.php?id=86947',
    },
  ],
  'firstid': 304379,
  'lastid': 304379,
};

Map<String, dynamic> _calendarEvent(
  int id,
  String module,
  String type,
  DateTime start,
  int durationSec, {
  String location = '',
}) => {
  'id': id,
  'name': module == 'attendance'
      ? 'Attendance (Group BDA-2608)'
      : 'Quiz 1 opens',
  'modulename': module,
  'eventtype': type,
  'timestart': sec(start),
  'timeduration': durationSec,
  'location': location,
  'course': {'id': 2543, 'fullname': 'Calculus 1 | Teacher F'},
  'url': 'https://lms.astanait.edu.kz/mod/$module/view.php?id=1',
};

final _monthly = {
  'weeks': [
    {
      'days': [
        {
          'mday': 1,
          'events': [
            _calendarEvent(
              1,
              'attendance',
              'attendance',
              DateTime(2026, 10, 1, 9),
              6600,
              location: 'C1.3.240',
            ),
            _calendarEvent(2, 'quiz', 'open', DateTime(2026, 10, 1, 8), 0),
          ],
        },
        {'mday': 2, 'events': []},
      ],
    },
  ],
};

final _contents = [
  {
    'id': 10,
    'name': 'General',
    'section': 0,
    'modules': [
      {
        'id': 501,
        'name': 'Syllabus',
        'modname': 'resource',
        'url': 'https://lms.astanait.edu.kz/mod/resource/view.php?id=501',
      },
      {'id': 502, 'name': 'Welcome', 'modname': 'label'},
    ],
  },
  {
    'id': 11,
    'name': 'Week 1',
    'section': 1,
    'modules': [
      {'id': 503, 'name': 'Slides', 'modname': 'folder', 'url': 'u3'},
      {'id': 504, 'name': 'Video', 'modname': 'url', 'url': 'u4'},
      {'id': 505, 'name': 'Reading', 'modname': 'page', 'url': 'u5'},
      {'id': 506, 'name': 'Homework', 'modname': 'assign', 'url': 'u6'},
    ],
  },
];

Map<String, dynamic> _gradeItems({bool graded = true}) => {
  'usergrades': [
    {
      'courseid': 2543,
      'userid': 1,
      'gradeitems': [
        {
          'id': 1,
          'itemname': 'Register Midterm',
          'itemtype': 'manual',
          'graderaw': graded ? 80.0 : null,
          'gradeformatted': graded ? '80,00' : '-',
          'grademin': 0,
          'grademax': 100,
          'rangeformatted': '0&ndash;100',
        },
        {
          'id': 2,
          'itemname': 'Register Endterm',
          'itemtype': 'manual',
          'graderaw': null,
          'gradeformatted': graded ? '90,00' : '-',
          'grademin': 0,
          'grademax': 100,
        },
        {
          'id': 3,
          'itemname': 'Final exam',
          'itemtype': 'mod',
          'itemmodule': 'quiz',
          'graderaw': null,
          'gradeformatted': '-',
          'grademin': 0,
          'grademax': 100,
        },
        {
          'id': 4,
          'itemname': null,
          'itemtype': 'course',
          'graderaw': graded ? 51.0 : 0.0,
          'gradeformatted': graded ? '51,00' : '0,00',
          'grademin': 0,
          'grademax': 100,
        },
      ],
    },
  ],
  'warnings': [],
};

Map<String, dynamic> ok(Object? data) => {'data': data};
Map<String, dynamic> err(String m) => {'error': m};

void main() {
  test('parseEnrolledCourses', () {
    final c = parseEnrolledCourses(_enrolled, classification: 'inprogress');
    expect(c, hasLength(2));
    expect(c[0].lmsCourseId, 2543);
    expect(c[0].title, 'Calculus 1');
    expect(c[0].teacherName, 'Teacher F');
    expect(c[0].classification, 'inprogress');
    expect(c[0].total, isNull);
    expect(c[1].title, 'Introduction to Programming & Logic');
    expect(c[1].teacherName, isNull);
  });

  test('parseActionEvents', () {
    final e = parseActionEvents(_actionEvents);
    expect(e, hasLength(1));
    expect(e[0].type, LmsEventType.deadline);
    expect(e[0].lmsEventId, 304379);
    expect(e[0].lmsCourseId, 2543);
    expect(e[0].courseTitle, 'Calculus 1');
    expect(e[0].moduleName, 'assign');
    expect(e[0].startsAt, DateTime(2026, 10, 1, 23, 59));
    expect(
      e[0].url,
      'https://lms.astanait.edu.kz/mod/assign/view.php?id=86947',
    );
  });

  test('parseCalendarView: monthly weeks/days and flat events', () {
    final e = parseCalendarView(_monthly);
    expect(e, hasLength(2));
    final cls = e.firstWhere((x) => x.lmsEventId == 1);
    expect(cls.type, LmsEventType.classSession);
    expect(cls.startsAt, DateTime(2026, 10, 1, 9));
    expect(cls.durationMin, 110);
    expect(cls.location, 'C1.3.240');
    expect(cls.courseTitle, 'Calculus 1');
    final quiz = e.firstWhere((x) => x.lmsEventId == 2);
    expect(quiz.type, LmsEventType.other);
    expect(quiz.durationMin, isNull);
    expect(quiz.location, isNull);

    final flat = parseCalendarView({
      'events': [
        _calendarEvent(
          7,
          'attendance',
          'attendance',
          DateTime(2026, 10, 2, 11),
          3000,
        ),
      ],
    });
    expect(flat.single.durationMin, 50);
  });

  test('parseCourseContents (core_course_get_contents)', () {
    final m = parseCourseContents(_contents, 2543, 'Calculus 1');
    expect(m.map((x) => x.title), [
      'Syllabus',
      'Slides',
      'Video',
      'Reading',
      'Homework',
    ]);
    expect(m.map((x) => x.materialType), [
      'file',
      'folder',
      'url',
      'page',
      'other',
    ]);
    expect(m.first.lmsModuleId, 501);
    expect(m.first.sectionTitle, 'General');
    expect(m[1].sectionTitle, 'Week 1');
    expect(m.first.lmsCourseId, 2543);
    expect(m.first.courseTitle, 'Calculus 1');
  });

  group('applyGradeItems', () {
    const base = LmsCourseData(lmsCourseId: 2543, title: 'Calculus 1');

    test('fills components; graderaw first, gradeformatted as fallback', () {
      final c = applyGradeItems(base, _gradeItems());
      expect(c.midterm, 80.0);
      expect(c.endterm, 90.0);
      expect(c.finalExam, isNull);
      expect(c.total, 51.0);
      final items = (jsonDecode(c.gradeItemsJson!) as List).cast<Map>();
      expect(items.map((i) => i['name']), [
        'Register Midterm',
        'Register Endterm',
        'Final exam',
      ]);
      expect(items.first['range'], '0–100');
      expect(items[1]['range'], '0–100');
    });

    test('nothing graded -> all null, total null (not 0)', () {
      final c = applyGradeItems(base, _gradeItems(graded: false));
      expect(c.midterm, isNull);
      expect(c.total, isNull);
    });

    test('malformed json keeps the base', () {
      expect(applyGradeItems(base.copyWith(total: 60), {'x': 1}).total, 60);
    });
  });

  group('buildImportResult', () {
    test('ajax course error + html overview -> courses from HTML', () {
      final r = buildImportResult({
        'ajax': {
          'courses': {
            'inprogress': err('access denied'),
            'past': err('access denied'),
          },
          'deadlines': ok(_actionEvents),
          'calendar': [ok(_monthly)],
          'contents': <String, dynamic>{},
          'gradeItems': <String, dynamic>{},
        },
        'html': {
          'overview': ok(fixture('grades_overview.html')),
          'profile': ok(fixture('profile.html')),
          'gradeReports': <String, dynamic>{},
        },
      });
      expect(r.courses, hasLength(6));
      expect(r.courses.first.title, 'Physical Education (Athletics)');
      expect(r.courses.every((c) => c.total == null), isTrue);
      expect(r.errors.containsKey('courses'), isFalse);
      expect(r.errors.containsKey('grades'), isFalse);
      expect(r.profile!.fullName, 'Student Test');
      expect(
        r.events.where((e) => e.type == LmsEventType.deadline),
        hasLength(1),
      );
      expect(
        r.events.where((e) => e.type == LmsEventType.classSession),
        hasLength(1),
      );
    });

    test('ajax courses + grade items + contents preferred', () {
      final r = buildImportResult({
        'ajax': {
          'courses': {
            'inprogress': ok(_enrolled),
            'past': ok({'courses': []}),
          },
          'deadlines': ok(_actionEvents),
          'calendar': [ok(_monthly)],
          'contents': {'2543': ok(_contents), '2614': ok(<Object>[])},
          'gradeItems': {'2543': ok(_gradeItems()), '2614': err('nope')},
        },
        'html': {
          'overview': err('HTTP 500'),
          'profile': ok(fixture('profile.html')),
          'gradeReports': {'2614': err('HTTP 500')},
        },
      });
      expect(r.errors, isEmpty);
      expect(r.courses, hasLength(2));
      final calc = r.courses.firstWhere((c) => c.lmsCourseId == 2543);
      expect(calc.classification, 'inprogress');
      expect(calc.midterm, 80.0);
      expect(calc.total, 51.0);
      expect(r.courses.firstWhere((c) => c.lmsCourseId == 2614).total, isNull);
      expect(r.materials, hasLength(5));
      expect(r.materials.first.courseTitle, 'Calculus 1');
    });

    test(
      'both grade sources failing -> errors[grades], other kinds filled',
      () {
        final r = buildImportResult({
          'ajax': {
            'courses': {'inprogress': err('denied'), 'past': err('denied')},
            'deadlines': ok(_actionEvents),
            'calendar': [ok(_monthly)],
            'contents': <String, dynamic>{},
            'gradeItems': <String, dynamic>{},
          },
          'html': {
            'overview': err('HTTP 500'),
            'profile': ok(fixture('profile.html')),
            'gradeReports': <String, dynamic>{},
          },
        });
        expect(r.errors['grades'], isNotNull);
        expect(
          r.errors['courses'],
          isNotNull,
        ); // importer must not delete courses
        expect(r.courses, isEmpty);
        expect(r.events, isNotEmpty);
        expect(r.profile, isNotNull);
        expect(r.errors.containsKey('deadlines'), isFalse);
        expect(r.errors.containsKey('classes'), isFalse);
        expect(r.errors.containsKey('profile'), isFalse);
      },
    );

    test('calendar html fallback when ajax calendar and deadlines fail', () {
      final r = buildImportResult({
        'ajax': {
          'courses': {
            'inprogress': ok(_enrolled),
            'past': ok({'courses': []}),
          },
          'deadlines': err('denied'),
          'calendar': [err('denied')],
          'contents': {'2543': err('denied'), '2614': err('denied')},
          'gradeItems': <String, dynamic>{},
        },
        'html': {
          'overview': err('HTTP 500'),
          'profile': err('HTTP 500'),
          'calendar': [ok(fixture('calendar_month.html'))],
          'contents': {'2543': err('HTTP 500'), '2614': err('HTTP 500')},
          'gradeReports': <String, dynamic>{},
        },
      });
      expect(
        r.events.where((e) => e.type == LmsEventType.classSession),
        hasLength(76),
      );
      expect(
        r.events.where((e) => e.type == LmsEventType.deadline),
        hasLength(19),
      );
      expect(r.errors.containsKey('deadlines'), isFalse);
      expect(r.errors.containsKey('classes'), isFalse);
      expect(r.errors['materials'], isNotNull);
      expect(r.errors['profile'], isNotNull);
      expect(r.profile, isNull);
    });

    test('garbage input never throws, reports every kind', () {
      final r = buildImportResult(<String, dynamic>{});
      for (final k in [
        'courses',
        'grades',
        'deadlines',
        'classes',
        'profile',
      ]) {
        expect(r.errors[k], isNotNull, reason: k);
      }
    });
  });

  group('grade normalisation', () {
    const base = LmsCourseData(lmsCourseId: 1, title: 'C');

    Map<String, dynamic> items(List<Map<String, dynamic>> rows) => {
      'usergrades': [
        {'gradeitems': rows},
      ],
    };

    test('graderaw is scaled to percent by grademin/grademax', () {
      final c = applyGradeItems(
        base,
        items([
          {
            'itemname': 'Register Midterm',
            'itemtype': 'manual',
            'graderaw': 30.0,
            'grademin': 0,
            'grademax': 40,
          },
          {
            'itemname': 'Register Endterm',
            'itemtype': 'manual',
            'graderaw': 15.0,
            'grademin': 10,
            'grademax': 20,
          },
          {
            'itemtype': 'course',
            'graderaw': 150.0,
            'grademin': 0,
            'grademax': 200,
          },
        ]),
      );
      expect(c.midterm, 75.0);
      expect(c.endterm, 50.0);
      expect(c.total, 75.0);
    });

    test('percentageformatted is preferred when parseable', () {
      final c = applyGradeItems(
        base,
        items([
          {
            'itemname': 'Register Midterm',
            'itemtype': 'manual',
            'graderaw': 30.0,
            'grademax': 40,
            'percentageformatted': '62,50 %',
          },
          {
            'itemname': 'Register Endterm',
            'itemtype': 'manual',
            'graderaw': 30.0,
            'grademax': 40,
            'percentageformatted': '-',
          },
        ]),
      );
      expect(c.midterm, 62.5);
      expect(c.endterm, 75.0);
    });

    test('scores are clamped to 0..100, non-finite becomes null', () {
      final c = applyGradeItems(
        base,
        items([
          {
            'itemname': 'Register Midterm',
            'itemtype': 'manual',
            'graderaw': 130.0,
            'grademax': 100,
          },
          {
            'itemname': 'Register Endterm',
            'itemtype': 'manual',
            'graderaw': -5.0,
            'grademax': 100,
          },
          {
            'itemname': 'Final exam',
            'itemtype': 'manual',
            'graderaw': double.nan,
            'grademax': 100,
          },
          {'itemtype': 'course', 'graderaw': 250.0, 'grademax': 100},
        ]),
      );
      expect(c.midterm, 100.0);
      expect(c.endterm, 0.0);
      expect(c.finalExam, isNull);
      expect(c.total, 100.0);
    });

    test('HTML report: grade with a 0–40 range is scaled to percent', () {
      const html = '''
<table class="user-grade"><tbody>
<tr><th class="column-itemname"><span class="gradeitemheader">Register Midterm</span></th>
<td class="column-grade">30,00</td><td class="column-range">0&ndash;40</td></tr>
<tr><th class="column-itemname"><span class="gradeitemheader">Register Endterm</span></th>
<td class="column-grade">90,00</td><td class="column-range">0&ndash;100</td></tr>
<tr><th class="column-itemname courseitem"><span class="gradeitemheader">Course total</span></th>
<td class="column-grade">60,00</td><td class="column-range">0-120</td></tr>
</tbody></table>''';
      final c = applyCourseGradeReport(base, html);
      expect(c.midterm, 75.0);
      expect(c.endterm, 90.0);
      expect(c.total, 50.0);
    });
  });

  group('partial imports', () {
    Map<String, dynamic> input({
      required Map<String, dynamic> courses,
      Object? overview,
      Map<String, dynamic> contents = const {},
      Map<String, dynamic> contentPages = const {},
      Map<String, dynamic> gradeItems = const {},
    }) => {
      'ajax': {
        'courses': courses,
        'deadlines': ok(_actionEvents),
        'calendar': [ok(_monthly)],
        'contents': contents,
        'gradeItems': gradeItems,
      },
      'html': {
        'overview': overview ?? err('HTTP 500'),
        'profile': ok(fixture('profile.html')),
        'contents': contentPages,
        'gradeReports': <String, dynamic>{},
      },
    };

    test('one failed classification without HTML cover -> courses and '
        'materials errors', () {
      final r = buildImportResult(
        input(
          courses: {'inprogress': ok(_enrolled), 'past': err('HTTP 500')},
          contents: {'2543': ok(_contents), '2614': ok(<Object>[])},
        ),
      );
      expect(r.errors['courses'], isNotNull);
      expect(r.errors['materials'], isNotNull);
      expect(r.courses, hasLength(2));
    });

    test('missing classification counts as failed', () {
      final r = buildImportResult(
        input(courses: {'inprogress': ok(_enrolled)}),
      );
      expect(r.errors['courses'], isNotNull);
    });

    test('failed classification covered by the overview -> no error; '
        'the rest of the overview is classified', () {
      final r = buildImportResult(
        input(
          courses: {'inprogress': ok(_enrolled), 'past': err('HTTP 500')},
          overview: ok(fixture('grades_overview.html')),
          contents: {'2543': ok(_contents), '2614': ok(<Object>[])},
        ),
      );
      expect(r.errors.containsKey('courses'), isFalse);
      expect(r.errors.containsKey('materials'), isFalse);
      expect(r.courses, hasLength(6));
      final byId = {for (final c in r.courses) c.lmsCourseId: c};
      expect(byId[2543]!.classification, 'inprogress');
      expect(byId[2752]!.classification, 'past');
    });

    test('HTML-only courses (all AJAX failed) are treated as inprogress', () {
      final r = buildImportResult(
        input(
          courses: {'inprogress': err('denied'), 'past': err('denied')},
          overview: ok(fixture('grades_overview.html')),
        ),
      );
      expect(r.errors.containsKey('courses'), isFalse);
      expect(r.courses, hasLength(6));
      expect(r.courses.every((c) => c.classification == 'inprogress'), isTrue);
    });

    test('empty course list -> materials error (nothing to scope by)', () {
      final r = buildImportResult(
        input(
          courses: {
            'inprogress': ok({'courses': []}),
            'past': ok({'courses': []}),
          },
        ),
      );
      expect(r.errors.containsKey('courses'), isFalse);
      expect(r.errors['materials'], isNotNull);
    });

    test('materialCourseIds lists only courses whose contents loaded', () {
      final r = buildImportResult(
        input(
          courses: {
            'inprogress': ok(_enrolled),
            'past': ok({'courses': []}),
          },
          contents: {'2543': ok(_contents), '2614': err('denied')},
          contentPages: {'2614': err('HTTP 500')},
        ),
      );
      expect(r.materialCourseIds, {2543});
      expect(r.errors['materials'], isNotNull);
    });

    test('per-course grade failure is reported in failedGradeCourseIds', () {
      final r = buildImportResult(
        input(
          courses: {
            'inprogress': ok(_enrolled),
            'past': ok({'courses': []}),
          },
          contents: {'2543': ok(_contents), '2614': ok(<Object>[])},
          gradeItems: {'2543': ok(_gradeItems()), '2614': err('nope')},
        ),
      );
      expect(r.failedGradeCourseIds, {2614});
      expect(r.errors.containsKey('grades'), isFalse);
    });
  });

  test(
    'kMoodleImportScript defines studyplanImport with AJAX and HTML fallback',
    () {
      expect(
        kMoodleImportScript,
        contains('async function studyplanImport(sinceSec, untilSec)'),
      );
      expect(kMoodleImportScript, contains('M.cfg.sesskey'));
      expect(kMoodleImportScript, contains('/lib/ajax/service.php?sesskey='));
      for (final fn in [
        'core_course_get_enrolled_courses_by_timeline_classification',
        'core_calendar_get_action_events_by_timesort',
        'core_calendar_get_calendar_monthly_view',
        'core_course_get_contents',
        'gradereport_user_get_grade_items',
        '/grade/report/overview/index.php',
        '/course/user.php?mode=grade&id=',
        '/user/profile.php',
        '/calendar/view.php?view=month',
        '/course/view.php?id=',
      ]) {
        expect(kMoodleImportScript, contains(fn), reason: fn);
      }
      expect(kMoodleImportScript, isNot(contains('document.cookie')));
    },
  );
}
