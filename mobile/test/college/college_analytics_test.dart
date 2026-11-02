import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/college/data/college_models.dart';
import 'package:studyplan/features/college/domain/college_analytics.dart';

SnGrade _g(String date, double? value, {bool absent = false}) => SnGrade(
      date: date,
      value: value,
      label: absent ? 'Н' : '${value?.toInt() ?? ''}',
      absent: absent,
    );

void main() {
  final subjects = [
    SnSubject(id: '1', name: 'Базы данных', average: 88, absences: 1, grades: [
      _g('2026-09-10', 80),
      _g('2026-09-20', 90),
      _g('2026-10-05', 95),
      _g('2026-10-06', null, absent: true),
    ]),
    SnSubject(id: '2', name: 'Алгоритмы', average: 45, absences: 3, grades: [
      _g('2026-09-15', 40),
      _g('2026-10-15', 50),
    ]),
    const SnSubject(id: '3', name: 'Физкультура'),
  ];

  test('monthlyAverages groups numeric marks by month, oldest first', () {
    final months = monthlyAverages(subjects);
    expect(months.map((m) => m.$1), [DateTime(2026, 9), DateTime(2026, 10)]);
    expect(months[0].$2, closeTo((80 + 90 + 40) / 3, 1e-9));
    expect(months[0].$3, 3);
    expect(months[1].$2, closeTo((95 + 50) / 2, 1e-9));
  });

  test('lastMonthTrend is the change between the last two months', () {
    expect(lastMonthTrend(subjects), closeTo(72.5 - 70, 1e-9));
    expect(lastMonthTrend(subjects.take(0)), isNull);
  });

  test('markBands splits marks at 90 / 70 / 50 and skips absences', () {
    final bands = markBands(subjects);
    expect(bands.excellent, 2); // 90, 95
    expect(bands.good, 1); // 80
    expect(bands.satisfactory, 1); // 50
    expect(bands.failing, 1); // 40
    expect(bands.total, 5);
  });

  test('subjects are ranked by average and by absences', () {
    expect(subjectsByAverage(subjects).map((s) => s.name), ['Базы данных', 'Алгоритмы']);
    expect(subjectsByAbsences(subjects).map((s) => s.absences), [3, 1]);
  });

  test('recentAverage uses the last marks by date', () {
    expect(recentAverage(subjects[0], count: 2), closeTo((90 + 95) / 2, 1e-9));
    expect(recentAverage(subjects[2]), isNull);
  });

  test('snapshot parsing sorts current assignments by deadline', () {
    final snap = SnSnapshot.fromJson({
      'profile': {'group': 'ПО2501', 'course': 2},
      'subjects': [],
      'stats': {'gpa': 81.5, 'grades_count': 10},
      'assignments': [
        {'id': 1, 'title': 'B', 'subject': 'x', 'expires_at': '2026-11-20T10:00:00Z', 'is_current': true},
        {'id': 2, 'title': 'A', 'subject': 'x', 'expires_at': '2026-11-10T10:00:00Z', 'is_current': true},
        {'id': 3, 'title': 'C', 'subject': 'x', 'status': 'Проверено', 'is_current': false},
      ],
      'synced_at': '2026-11-02T08:00:00Z',
    });
    expect(snap.group, 'ПО2501');
    expect(snap.course, 2);
    expect(snap.stats.gpa, 81.5);
    expect(snap.currentAssignments.map((a) => a.title), ['A', 'B']);
    expect(snap.pastAssignments.single.isDone, isTrue);
    expect(snap.syncedAt, isNotNull);
  });
}
