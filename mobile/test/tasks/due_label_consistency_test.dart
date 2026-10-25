import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/home/presentation/screens/home_screen.dart';
import 'package:studyplan/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Monday 26 Oct 2026, 09:30.
final _now = DateTime(2026, 10, 26, 9, 30);
const _user = 'u1';

BigInt _ms(DateTime d) => BigInt.from(d.millisecondsSinceEpoch);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

Future<AppDatabase> _pump(WidgetTester tester, Widget Function(AppDatabase) screen,
    {required DateTime due}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.runAsync(() => db.into(db.tasks).insert(TasksCompanion.insert(
        id: 't1',
        userId: _user,
        title: 'Лабораторная работа 3',
        dueDate: Value(_ms(due)),
        updatedAt: _ms(_now),
      )));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en'), Locale('kk')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: screen(db),
  ));
  await _settle(tester);
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> expectSameLabel(WidgetTester tester, DateTime due, String expected) async {
    var db = await _pump(
      tester,
      (db) => HomeScreen(db: db, userId: _user, onOpenTab: (_) {}, clock: () => _now),
      due: due,
    );
    expect(find.text(expected), findsOneWidget, reason: 'Home');
    await _dispose(tester, db);

    db = await _pump(
      tester,
      (db) => TasksScreen(db: db, userId: _user, clock: () => _now),
      due: due,
    );
    expect(find.text(expected), findsOneWidget, reason: 'Tasks');
    await _dispose(tester, db);
  }

  testWidgets('Home and Tasks show the same due label (tomorrow)', (tester) async {
    await expectSameLabel(tester, DateTime(2026, 10, 27, 18), 'Завтра, 18:00');
  });

  testWidgets('Home and Tasks show the same due label (later this week)',
      (tester) async {
    final due = DateTime(2026, 10, 29, 23, 59);
    // formatDue's weekday form for dates within 6 days.
    await expectSameLabel(tester, due, DateFormat.MMMEd('ru').format(due));
  });
}
