import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/profile/data/deadline_reminders.dart';
import 'package:studyplan/features/profile/presentation/screens/profile_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

Future<AppDatabase> _pump(
  WidgetTester tester,
  AppSettings settings, {
  Size size = const Size(390, 900),
  ThemeData? theme,
  VoidCallback? onImportLms,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ProfileScreen(
        db: db,
        apiClient: ApiClient(baseUrl: 'http://127.0.0.1:3000/api'),
        settings: settings,
        user: const {'id': 'u1', 'name': 'Test User', 'email': 'u@example.com'},
        onLogout: () {},
        onImportLms: onImportLms,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows name, email and settings rows without overflow', (
    tester,
  ) async {
    final db = await _pump(tester, AppSettings(), size: const Size(360, 1200));

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('u@example.com'), findsOneWidget);
    expect(find.text('Тема'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Системная'), findsOneWidget);
    expect(find.text('Напоминания о дедлайнах'), findsOneWidget);
    expect(find.text('Экспорт расписания (.ics)'), findsOneWidget);
    expect(find.text('Сервер'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    // No LMS block without a profile and without an import callback.
    expect(find.text('Подключить LMS'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('content column is at most 720 px wide at 1280 px', (
    tester,
  ) async {
    final db = await _pump(tester, AppSettings(), size: const Size(1280, 900));

    for (final group in tester.widgetList(find.byType(ListGroup))) {
      final width = tester.getSize(find.byWidget(group)).width;
      expect(width, lessThanOrEqualTo(720));
    }
    final themeRow = find.ancestor(
      of: find.text('Тема'),
      matching: find.byType(ListGroup),
    );
    expect(tester.getSize(themeRow).width, 720);
    expect(tester.getTopLeft(themeRow).dx, (1280 - 720) / 2);
    await _dispose(tester, db);
  });

  testWidgets('choosing «Тёмная» sets dark theme mode', (tester) async {
    final settings = AppSettings();
    final db = await _pump(tester, settings);

    await tester.tap(find.text('Тема'));
    await tester.pumpAndSettle();
    expect(find.text('Светлая'), findsOneWidget);
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.themeModeKey), 'dark');
    await _dispose(tester, db);
  });

  testWidgets('language list shows 4 options including Қазақша', (
    tester,
  ) async {
    final settings = AppSettings();
    final db = await _pump(tester, settings);

    await tester.tap(find.text('Язык'));
    await tester.pumpAndSettle();

    for (final label in ['Системный', 'Русский', 'English', 'Қазақша']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();
    expect(settings.locale, const Locale('kk'));
    await _dispose(tester, db);
  });

  testWidgets('LMS profile from preferences is shown', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileScreen.lmsProfileKey: jsonEncode({
        'fullName': 'Student Test',
        'email': 'student@example.com',
      }),
    });
    final db = await _pump(tester, AppSettings(), onImportLms: () {});

    expect(find.text('Student Test'), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('Подключить LMS'), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('without LMS profile the connect row calls onImportLms', (
    tester,
  ) async {
    var opened = 0;
    final db = await _pump(tester, AppSettings(), onImportLms: () => opened++);

    await tester.tap(find.text('Подключить LMS'));
    expect(opened, 1);
    await _dispose(tester, db);
  });

  testWidgets('reminder switch is persisted', (tester) async {
    final db = await _pump(tester, AppSettings(), theme: AppTheme.dark());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(DeadlineReminders.prefsKey), isTrue);
    await _dispose(tester, db);
  });

  testWidgets('logout asks for confirmation', (tester) async {
    var loggedOut = false;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProfileScreen(
          db: db,
          apiClient: ApiClient(),
          settings: AppSettings(),
          user: const {'id': 'u1', 'name': 'Test User'},
          onLogout: () => loggedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    expect(loggedOut, isFalse);
    await tester.tap(find.text('Выйти').last);
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    await _dispose(tester, db);
  });

  group('DeadlineReminders.upcoming', () {
    test(
      'returns own and group tasks and LMS deadlines in the future',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime(2026, 10, 26, 12);
        final future = now.add(const Duration(days: 2)).millisecondsSinceEpoch;
        final past = now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch;
        final ts = BigInt.from(now.millisecondsSinceEpoch);
        BigInt b(int v) => BigInt.from(v);

        Future<void> task(
          String id,
          String userId, {
          int? due,
          String status = 'inbox',
          bool isGroup = false,
        }) {
          return db
              .into(db.tasks)
              .insert(
                TasksCompanion.insert(
                  id: id,
                  userId: userId,
                  title: id,
                  dueDate: Value(due == null ? null : b(due)),
                  status: Value(status),
                  isGroup: Value(isGroup),
                  groupId: Value(isGroup ? 'g1' : null),
                  updatedAt: ts,
                ),
              );
        }

        await task('own', 'u1', due: future);
        await task('done', 'u1', due: future, status: 'completed');
        await task('old', 'u1', due: past);
        await task('nodue', 'u1');
        await task('group', 'u2', due: future, isGroup: true);
        await task('foreign', 'u2', due: future);
        await db
            .into(db.lmsEvents)
            .insert(
              LmsEventsCompanion.insert(
                id: 'lms1',
                userId: 'u1',
                title: 'Quiz',
                eventType: const Value('deadline'),
                startsAt: b(future + 1),
                updatedAt: ts,
              ),
            );

        final result = await DeadlineReminders(db)
            .upcoming('u1', groupId: 'g1', now: now);
        expect(
          result.map((d) => d.id),
          unorderedEquals(['own', 'group', 'lms1']),
        );
        expect(result.last.id, 'lms1');
      },
    );
  });
}
