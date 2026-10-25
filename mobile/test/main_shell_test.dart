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

Future<AppDatabase> _pumpShell(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
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
      apiClient: ApiClient(),
      settings: AppSettings(),
      user: const {'id': 'u1', 'name': 'Test User', 'email': 'u@example.com'},
      onLogout: () {},
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
}
