import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';
import 'package:studyplan/features/more/presentation/screens/more_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

import 'core/fake_sync_repository.dart';
import 'group/group_test_utils.dart' show fakeApi;
import 'main_shell/session_cleanup_test.dart' show seedRows;

late FakeSyncRepository _repo;

Future<AppDatabase> _pumpShell(
  WidgetTester tester,
  Size size, {
  Map<String, Object> prefs = const {},
  ApiClient? apiClient,
  VoidCallback? onLogout,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  if (seed != null) await seed(db);
  _repo = FakeSyncRepository(db);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('ru'),
    supportedLocales: kSupportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MainShellScreen(
      db: db,
      apiClient: apiClient ?? ApiClient(),
      settings: AppSettings(),
      user: const {'id': 'u1', 'name': 'Test User', 'email': 'u@example.com'},
      onLogout: onLogout ?? () {},
      syncRepository: _repo,
    ),
  ));
  await tester.pump();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  // Drift stream cleanup schedules a zero-duration timer.
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('phone width shows a bottom bar with 5 destinations',
      (tester) async {
    final db = await _pumpShell(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in ['Главная', 'Расписание', 'Задания', 'Оценки', 'Ещё']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('1000 px width shows a navigation rail', (tester) async {
    final db = await _pumpShell(tester, const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    await _dispose(tester, db);
  });

  testWidgets('bottom bar destinations have no duplicate tooltips',
      (tester) async {
    final db = await _pumpShell(tester, const Size(400, 800));
    for (final d in tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination))) {
      expect(d.tooltip, '');
    }
    await _dispose(tester, db);
  });

  testWidgets('wide window shows a labelled sidebar that switches tabs',
      (tester) async {
    final db = await _pumpShell(tester, const Size(1300, 800));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('StudyPlan'), findsWidgets);
    await tester.tap(find.text('Оценки').first);
    await tester.pump();
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
      AppTab.grades.index,
    );
    await _dispose(tester, db);
  });

  testWidgets('tapping a destination switches the body', (tester) async {
    final db = await _pumpShell(tester, const Size(800, 1000));

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack).first);
    expect(stack().index, AppTab.home.index);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Оценки'),
    ));
    await tester.pump();
    expect(stack().index, AppTab.grades.index);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Ещё'),
    ));
    await tester.pump();
    expect(stack().index, AppTab.more.index);
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('Профиль и настройки'), findsOneWidget);
    expect(find.text('Группа не выбрана'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('home empty state action opens the schedule tab',
      (tester) async {
    final db = await _pumpShell(tester, const Size(800, 1000));

    await tester.tap(find.text('Добавить расписание'));
    await tester.pump();
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
      AppTab.schedule.index,
    );
    await _dispose(tester, db);
  });

  testWidgets('shell syncs after the first frame and on resume',
      (tester) async {
    final db = await _pumpShell(tester, const Size(400, 800));
    await tester.pump();
    expect(_repo.syncCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_repo.syncCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_repo.syncCalls, 2);
    await _dispose(tester, db);
  });

  testWidgets('joining a group resets the cursor and syncs from 0',
      (tester) async {
    var inGroup = false;
    final api = fakeApi({
      'GET /groups/me': (_) => inGroup
          ? {
              'group': {'id': 'g1', 'title': 'BDA-2601', 'invite_code': 'ABC123'},
              'members': [
                {'id': 'u1', 'name': 'Test User'},
              ],
            }
          : {'group': null, 'members': <Object>[]},
      'POST /groups/join': (_) {
        inGroup = true;
        return {'ok': true};
      },
    });
    final db = await _pumpShell(
      tester,
      const Size(400, 900),
      prefs: {'studyplan_last_synced_at': 5000},
      apiClient: api,
    );
    await tester.pump();
    // Startup sync from the stored cursor.
    expect(_repo.cursorsAtSync, [5000]);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Ещё'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Группа не выбрана'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вступить по коду'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ABC123');
    await tester.tap(find.widgetWithText(FilledButton, 'Вступить'));
    await tester.pumpAndSettle();

    expect(inGroup, isTrue);
    expect(_repo.cursorsAtSync, [5000, 0]);
    await _dispose(tester, db);
  });

  testWidgets('logout clears session prefs and the local database',
      (tester) async {
    var loggedOut = false;
    final db = await _pumpShell(
      tester,
      const Size(800, 2000),
      prefs: {
        'jwt_token': 'jwt',
        'user_data': '{"id":"u1"}',
        'studyplan_last_synced_at': 123,
        'lms.profile': '{}',
        'group_members_cache': '[]',
        'group_materials_cache_g1': '[]',
        'pending_invite_code': 'ABC123',
      },
      onLogout: () => loggedOut = true,
      seed: seedRows,
    );

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Ещё'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль и настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти').last);
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'jwt_token',
      'user_data',
      'studyplan_last_synced_at',
      'lms.profile',
      'group_members_cache',
      'group_materials_cache_g1',
      'pending_invite_code',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    final rows = await tester.runAsync(() async => [
          ...await db.select(db.subjects).get(),
          ...await db.select(db.tasks).get(),
          ...await db.select(db.lmsCourses).get(),
        ]);
    expect(rows, isEmpty);
    await _dispose(tester, db);
  });
}
