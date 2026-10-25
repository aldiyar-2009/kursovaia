import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

// 2026-11-02 is a Monday of academic week 10 (even) counted from 1 September.
final _evenMonday = DateTime(2026, 11, 2);

Future<void> _pump(WidgetTester tester, AppDatabase db,
    {Size size = const Size(390, 844), ThemeData? theme}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light(),
    locale: const Locale('ru'),
    supportedLocales: kSupportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ScheduleScreen(db: db, userId: 'u1', today: _evenMonday),
  ));
  // Let drift streams emit.
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

BigInt _now() => BigInt.from(DateTime.now().millisecondsSinceEpoch);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  testWidgets('no lessons shows the empty state with «Добавить пару»',
      (tester) async {
    await _pump(tester, db);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Расписание пусто'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('Добавить пару'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('LMS class on the selected day is shown with «LMS»',
      (tester) async {
    await tester.runAsync(() => db.into(db.lmsEvents).insert(LmsEventsCompanion(
          id: const Value('e1'),
          userId: const Value('u1'),
          title: const Value('Attendance (Group BDA-2608)'),
          courseTitle: const Value('Linear Algebra'),
          eventType: const Value('class'),
          startsAt: Value(BigInt.from(
            DateTime(2026, 11, 2, 10, 0).millisecondsSinceEpoch,
          )),
          durationMin: const Value(50),
          updatedAt: Value(_now()),
        )));
    await _pump(tester, db);

    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('10 неделя · чётная'), findsOneWidget);
    expect(find.text('Linear Algebra'), findsOneWidget);
    expect(find.text('LMS'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('10:50'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('odd-week lesson is hidden on an even week', (tester) async {
    await tester.runAsync(() async {
      await db.into(db.subjects).insert(SubjectsCompanion(
            id: const Value('s1'),
            userId: const Value('u1'),
            title: const Value('Physics'),
            updatedAt: Value(_now()),
          ));
      await db.into(db.lessons).insert(LessonsCompanion(
            id: const Value('l1'),
            subjectId: const Value('s1'),
            userId: const Value('u1'),
            dayOfWeek: const Value(1),
            startTime: const Value('09:00'),
            endTime: const Value('09:50'),
            isEvenWeek: const Value(false),
            updatedAt: Value(_now()),
          ));
    });
    await _pump(tester, db, size: const Size(1300, 900));

    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Physics'), findsNothing);
    expect(find.text('В этот день пар нет'), findsOneWidget);

    // Next week (11, odd) the lesson appears.
    await tester.tap(find.byTooltip('Следующая неделя'));
    await tester.pump();
    expect(find.text('11 неделя · нечётная'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('add sheet creates a subject and a lesson', (tester) async {
    await _pump(tester, db, size: const Size(360, 740));

    await tester.tap(find.text('Добавить пару'));
    await tester.pumpAndSettle();
    expect(find.text('Аудитория'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, 'Physics');
    await tester.enterText(find.byType(TextFormField).last, '305');
    await tester.tap(find.text('Сохранить'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Лекция, 305'), findsOneWidget);
    final lesson = await tester.runAsync(() => db.select(db.lessons).getSingle());
    expect(lesson!.syncStatus, 'pending_create');
    expect(lesson.isEvenWeek, isNull);
    expect(lesson.dayOfWeek, 1);
    await _dispose(tester, db);
  });

  testWidgets('lesson sheet has a handle, close button and full-width save',
      (tester) async {
    await _pump(tester, db, size: const Size(390, 844));

    await tester.tap(find.byTooltip('Добавить пару'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-sheet-handle')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    expect(save, findsOneWidget);
    // Sheet is as wide as the screen here; the button spans it minus 16 px
    // gutters on both sides.
    expect(tester.getSize(save).width, 390 - 32);
    expect(tester.getTopLeft(save).dx, 16);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-sheet-handle')), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('time picker opens in 24-hour input mode', (tester) async {
    await _pump(tester, db, size: const Size(390, 844));

    await tester.tap(find.byTooltip('Добавить пару'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();

    final picker = tester.widget<TimePickerDialog>(find.byType(TimePickerDialog));
    expect(picker.initialEntryMode, TimePickerEntryMode.input);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('app bar title starts at the content edge at 1280 px',
      (tester) async {
    await _pump(tester, db, size: const Size(1280, 900));

    final titleX = tester.getTopLeft(find.text('Расписание')).dx;
    final contentX = tester
        .getTopLeft(find.byKey(const ValueKey('schedule-mode-toggle')))
        .dx;
    expect(contentX, (1280 - 720) / 2);
    expect(titleX, contentX);
    await _dispose(tester, db);
  });

  testWidgets('switching to «Календарь» shows academic events',
      (tester) async {
    await _pump(tester, db, size: const Size(360, 740), theme: AppTheme.dark());

    await tester.tap(find.text('Календарь'));
    await tester.pump();

    expect(find.text('2026/2027 учебный год'), findsOneWidget);
    expect(find.text('I семестр'), findsOneWidget);
    expect(find.text('1 рубежная неделя'), findsOneWidget);
    expect(find.text('Сейчас'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });
}
