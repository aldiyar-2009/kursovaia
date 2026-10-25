import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/home/presentation/screens/home_screen.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Monday 26 Oct 2026, 09:30 local time.
final _now = DateTime(2026, 10, 26, 9, 30);
const _user = 'u1';

BigInt _ms(DateTime d) => BigInt.from(d.millisecondsSinceEpoch);

Future<void> _addLesson(AppDatabase db, {String start = '10:00', String end = '11:50'}) async {
  await db.into(db.subjects).insert(SubjectsCompanion.insert(
        id: 's1',
        userId: _user,
        title: 'Математический анализ',
        updatedAt: _ms(_now),
      ));
  await db.into(db.lessons).insert(LessonsCompanion.insert(
        id: 'l1',
        subjectId: 's1',
        userId: _user,
        dayOfWeek: _now.weekday,
        startTime: start,
        endTime: end,
        classroom: const Value('C1.3.240'),
        updatedAt: _ms(_now),
      ));
}

Future<AppDatabase> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  ThemeData? theme,
  Future<void> Function(AppDatabase db)? seed,
  List<AppTab>? opened,
  bool lmsImportAvailable = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  if (seed != null) await tester.runAsync(() => seed(db));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en'), Locale('kk')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: HomeScreen(
      db: db,
      userId: _user,
      clock: () => _now,
      onOpenTab: (tab) => opened?.add(tab),
      onOpenGroup: () {},
      lmsImportAvailable: lmsImportAvailable,
    ),
  ));
  await _settle(tester);
  return db;
}

/// Lets drift streams deliver their first values.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('empty database shows the first-steps checklist with 3 items',
      (tester) async {
    final opened = <AppTab>[];
    final db = await _pump(tester, opened: opened);

    expect(find.text('С чего начать'), findsOneWidget);
    expect(find.text('Добавить расписание'), findsOneWidget);
    expect(find.text('Импортировать оценки из LMS'), findsOneWidget);
    expect(find.text('Вступить в группу или создать'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    expect(find.text('Дедлайны'), findsNothing);
    expect(find.text('Оценки'), findsNothing);
    // App bar shows today's localized date.
    expect(find.text('Понедельник, 26 октября'), findsOneWidget);

    await tester.tap(find.text('Импортировать оценки из LMS'));
    expect(opened, [AppTab.grades]);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('a lesson today is shown with its time and room',
      (tester) async {
    final db = await _pump(tester, seed: _addLesson);

    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Математический анализ'), findsOneWidget);
    expect(find.text('10:00–11:50'), findsOneWidget);
    expect(find.text('Лекция, C1.3.240'), findsOneWidget);
    expect(find.text('через 30 мин'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('an ongoing lesson is labelled «Сейчас»', (tester) async {
    final db = await _pump(
      tester,
      seed: (db) => _addLesson(db, start: '09:00', end: '10:20'),
    );

    expect(find.text('Сейчас'), findsOneWidget);
    expect(find.text('ещё 50 мин'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('a task due tomorrow appears under «Дедлайны»', (tester) async {
    final opened = <AppTab>[];
    final db = await _pump(
      tester,
      opened: opened,
      seed: (db) async {
        await db.into(db.tasks).insert(TasksCompanion.insert(
              id: 't1',
              userId: _user,
              title: 'Лабораторная работа 3',
              subjectTitle: const Value('Физика'),
              dueDate: Value(_ms(DateTime(2026, 10, 27, 18, 0))),
              updatedAt: _ms(_now),
            ));
        // Completed and far-away tasks are not shown.
        await db.into(db.tasks).insert(TasksCompanion.insert(
              id: 't2',
              userId: _user,
              title: 'Сданное эссе',
              status: const Value('completed'),
              dueDate: Value(_ms(DateTime(2026, 10, 27, 18, 0))),
              updatedAt: _ms(_now),
            ));
        await db.into(db.tasks).insert(TasksCompanion.insert(
              id: 't3',
              userId: _user,
              title: 'Курсовая',
              dueDate: Value(_ms(DateTime(2026, 12, 20))),
              updatedAt: _ms(_now),
            ));
      },
    );

    expect(find.text('Дедлайны'), findsOneWidget);
    expect(find.text('Лабораторная работа 3'), findsOneWidget);
    expect(find.text('Физика'), findsOneWidget);
    expect(find.text('Завтра, 18:00'), findsOneWidget);
    expect(find.text('Сданное эссе'), findsNothing);
    expect(find.text('Курсовая'), findsNothing);

    await tester.tap(find.text('Все задания'));
    expect(opened, [AppTab.tasks]);
    await _dispose(tester, db);
  });

  testWidgets('recent grades show letter and total', (tester) async {
    final db = await _pump(
      tester,
      seed: (db) async {
        await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
              id: 'c1',
              userId: _user,
              title: 'Базы данных',
              total: const Value(91.5),
              updatedAt: _ms(_now),
            ));
        await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
              id: 'c2',
              userId: _user,
              title: 'Без оценки',
              updatedAt: _ms(_now),
            ));
      },
    );

    expect(find.text('Оценки'), findsOneWidget);
    expect(find.text('Базы данных'), findsOneWidget);
    expect(find.text('A-'), findsOneWidget);
    expect(find.text('91,5'), findsOneWidget);
    expect(find.text('Без оценки'), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('the schedule step disappears once a lesson exists',
      (tester) async {
    final db = await _pump(tester);
    expect(find.text('Добавить расписание'), findsOneWidget);

    // Written in the test zone: the live drift streams belong to it.
    final insert = _addLesson(db);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await insert;
    await tester.pump();

    expect(find.text('Добавить расписание'), findsNothing);
    expect(find.text('Импортировать оценки из LMS'), findsOneWidget);
    expect(find.text('Вступить в группу или создать'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('dark theme at 360 px and wide window render without overflow',
      (tester) async {
    Future<void> seed(AppDatabase db) async {
      await _addLesson(db, start: '09:00', end: '10:20');
      await db.into(db.lessons).insert(LessonsCompanion.insert(
            id: 'l2',
            subjectId: 's1',
            userId: _user,
            dayOfWeek: _now.weekday,
            startTime: '13:00',
            endTime: '14:50',
            classroom: const Value('Очень длинное название аудитории в корпусе C1'),
            updatedAt: _ms(_now),
          ));
      await db.into(db.lmsEvents).insert(LmsEventsCompanion.insert(
            id: 'e1',
            userId: _user,
            title: 'Очень длинное название задания из LMS, которое не помещается в строку',
            courseTitle: const Value('Объектно-ориентированное программирование'),
            eventType: const Value('deadline'),
            startsAt: _ms(DateTime(2026, 10, 29, 23, 59)),
            updatedAt: _ms(_now),
          ));
    }

    var db = await _pump(
      tester,
      size: const Size(360, 640),
      theme: AppTheme.dark(),
      seed: seed,
    );
    expect(find.text('Сейчас'), findsOneWidget);
    expect(find.text('Ещё сегодня'), findsOneWidget);
    expect(find.text('LMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);

    db = await _pump(tester, size: const Size(1400, 900), seed: seed);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('without LMS import (web) the grades step offers manual entry',
      (tester) async {
    final opened = <AppTab>[];
    final db = await _pump(tester, opened: opened, lmsImportAvailable: false);

    expect(find.text('Импортировать оценки из LMS'), findsNothing);
    expect(find.text('Добавить оценки'), findsOneWidget);
    expect(find.text('Введите баллы по предметам вручную'), findsOneWidget);
    await tester.tap(find.text('Добавить оценки'));
    expect(opened, [AppTab.grades]);
    await _dispose(tester, db);
  });

  testWidgets('section headers and the app bar title line up with the rows',
      (tester) async {
    Future<void> seed(AppDatabase db) => db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 't1',
            userId: _user,
            title: 'Лабораторная работа 3',
            dueDate: Value(_ms(DateTime(2026, 10, 27, 18, 0))),
            updatedAt: _ms(_now),
          ),
        );

    for (final size in const [Size(390, 844), Size(1400, 900)]) {
      final db = await _pump(tester, size: size, seed: seed);

      final groups = find.byType(ListGroup);
      expect(groups, findsNWidgets(2)); // deadlines + first steps
      final rowsX = tester.getTopLeft(groups.first).dx;
      expect(tester.getTopLeft(find.text('Дедлайны')).dx, rowsX);
      expect(tester.getTopLeft(find.text('С чего начать')).dx, rowsX);
      expect(tester.getTopLeft(groups.last).dx, rowsX);
      expect(tester.getTopLeft(find.text('Понедельник, 26 октября')).dx, rowsX);
      if (size.width < 600) expect(rowsX, 16);

      // Same toolbar height as the other tabs.
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
      expect(tester.takeException(), isNull);
      await _dispose(tester, db);
    }
  });
}
