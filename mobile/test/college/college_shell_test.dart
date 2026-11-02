import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/features/college/data/college_repository.dart';
import 'package:studyplan/features/college/presentation/college_grades_screen.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

import '../core/fake_sync_repository.dart';
import '../group/group_test_utils.dart' show fakeApi, offline, wrapApp;

const _snapshot = {
  'profile': {'group': 'ПО2501', 'course': 2},
  'subjects': [
    {
      'id': 1,
      'name': 'Базы данных',
      'teacher': 'Иванова А.',
      'average': 91.0,
      'absences': 0,
      'grades': [
        {'date': '2026-09-10', 'value': 90, 'label': '90', 'theme': 'SQL'},
        {'date': '2026-10-10', 'value': 92, 'label': '92', 'theme': 'Индексы'},
      ],
    },
    {
      'id': 2,
      'name': 'Алгоритмы',
      'average': 58.0,
      'absences': 2,
      'grades': [
        {'date': '2026-10-01', 'value': 58, 'label': '58'},
      ],
    },
  ],
  'stats': {'gpa': 80.0, 'grades_count': 3, 'excellent_count': 2, 'retakes_count': 0, 'absences': 2},
  'assignments': [
    {
      'id': 7,
      'title': 'Лабораторная 3',
      'subject': 'Базы данных',
      'expires_at': '2030-01-10T10:00:00Z',
      'status': 'В ожидании',
      'is_current': true,
    },
  ],
};

void main() {
  testWidgets('college shell: SmartNation grades, college tasks filter, no LMS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      // Timetable was imported before: no automatic import in this test.
      kCollegeGroupPrefsKey: 'ПО2501',
    });
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final api = fakeApi({
      'GET /college/snapshot': (_) => {'snapshot': _snapshot},
      'GET /events': (o) => throw offline(o),
      'GET /announcements': (o) => throw offline(o),
    });
    await tester.pumpWidget(wrapApp(MainShellScreen(
      db: db,
      apiClient: api,
      settings: AppSettings(),
      user: const {'id': 'u1', 'name': 'Студент', 'edition': 'college', 'sn_group': 'ПО2501'},
      onLogout: () {},
      syncRepository: FakeSyncRepository(db),
    )));
    await tester.pump();

    await tester.tap(find.text('Оценки'));
    await tester.pumpAndSettle();
    expect(find.byType(CollegeGradesScreen), findsOneWidget);
    expect(find.text('Под угрозой'), findsOneWidget);
    expect(find.text('Алгоритмы'), findsOneWidget); // average 58

    await tester.tap(find.text('Задания').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Колледж'));
    await tester.pumpAndSettle();
    expect(find.text('Лабораторная 3'), findsOneWidget);

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('more_lms_import')), findsNothing);
    expect(find.byKey(const ValueKey('more_events')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(db.close);
  });

  test('edition of a user falls back to the chosen one for guests', () {
    expect(AppEdition.ofUser(const {'edition': 'college'}), AppEdition.college);
    expect(AppEdition.ofUser(const {'id': 'guest'}, fallback: AppEdition.college), AppEdition.college);
    expect(AppEdition.ofUser(const {'id': 'x'}), AppEdition.university);
  });
}
