import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/features/grades/presentation/screens/course_detail_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/grades_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

Future<AppDatabase> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  Size size = const Size(390, 844),
  VoidCallback? onImportLms,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  if (seed != null) await tester.runAsync(() => seed(db));
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
    home: GradesScreen(db: db, userId: 'u1', onImportLms: onImportLms),
  ));
  await _settle(tester);
  return db;
}

/// Lets drift streams emit (they need real async) and rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

Future<void> _course(
  AppDatabase db,
  String id,
  String title, {
  double? midterm,
  double? endterm,
  double? finalExam,
  double? total,
  int credits = 5,
  String source = 'manual',
  String? classification,
}) {
  return db.lmsDao.upsertManualCourse(LmsCoursesCompanion(
    id: Value(id),
    userId: const Value('u1'),
    source: Value(source),
    title: Value(title),
    credits: Value(credits),
    classification: Value(classification),
    registerMidterm: Value(midterm),
    registerEndterm: Value(endterm),
    finalExam: Value(finalExam),
    total: Value(total),
  ));
}

void main() {
  testWidgets('empty shows EmptyState with import and manual actions',
      (tester) async {
    var imported = 0;
    final db = await _pump(tester, onImportLms: () => imported++);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Оценок пока нет'), findsOneWidget);
    expect(find.text('Импортировать из LMS'), findsOneWidget);
    expect(find.text('Добавить предмет вручную'), findsOneWidget);

    await tester.tap(find.text('Импортировать из LMS'));
    expect(imported, 1);

    await tester.tap(find.text('Добавить предмет вручную'));
    await tester.pumpAndSettle();
    expect(find.text('Новый предмет'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('without an import callback only manual entry is offered',
      (tester) async {
    final db = await _pump(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Импортировать из LMS'), findsNothing);
    expect(find.text('Добавить предмет вручную'), findsOneWidget);
    expect(
      find.text('Импорт из LMS пока недоступен. Оценки можно ввести вручную.'),
      findsOneWidget,
    );

    await _dispose(tester, db);
  });

  testWidgets('manual course 80/90 without final needs 97.5 for 90',
      (tester) async {
    final db = await _pump(
      tester,
      seed: (db) => _course(db, 'c1', 'Calculus', midterm: 80, endterm: 90),
    );

    expect(find.text('Calculus'), findsOneWidget);
    await tester.tap(find.text('Calculus'));
    await _settle(tester);

    expect(find.byType(CourseDetailScreen), findsOneWidget);
    // Admission 85 -> (90 - 0.6*85) / 0.4 = 97.5; pass needs at least 50.
    expect(find.text('нужно 97.5'), findsOneWidget);
    expect(find.text('нужно 50.0'), findsOneWidget);
    expect(find.text('85.0'), findsOneWidget); // admission rating
    expect(find.text('Что будет, если…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _dispose(tester, db);
  });

  testWidgets('course without total shows «нет оценки» and is not averaged',
      (tester) async {
    final db = await _pump(
      tester,
      seed: (db) async {
        await _course(db, 'c1', 'Algebra', total: 80, source: 'lms',
            classification: 'inprogress');
        await _course(db, 'c2', 'Biology', source: 'lms',
            classification: 'inprogress');
      },
    );

    expect(find.text('нет оценки'), findsOneWidget);
    // Average over Algebra only: 80.0 (would be 40.0 if null counted as 0).
    expect(find.text('Средний балл'), findsOneWidget);
    expect(find.text('80.0'), findsNWidgets(2)); // summary + Algebra row
    expect(find.text('40.0'), findsNothing);

    await _dispose(tester, db);
  });

  testWidgets('manual form saves a course that shows in the list',
      (tester) async {
    final db = await _pump(tester);

    await tester.tap(find.text('Добавить предмет вручную'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Discrete Math');
    await tester.enterText(fields.at(2), '70');
    await tester.enterText(fields.at(3), '80');
    await tester.enterText(fields.at(4), '90');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await _settle(tester);

    final saved = await tester.runAsync(() => db.lmsDao.watchCourses('u1').first);
    expect(saved!.single.title, 'Discrete Math');
    expect(saved.single.source, 'manual');
    // 0.6 * 75 + 0.4 * 90 = 81.0
    expect(saved.single.total, 81.0);
    expect(find.text('Discrete Math'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('past courses are collapsed under «Прошлые семестры»',
      (tester) async {
    final db = await _pump(
      tester,
      seed: (db) async {
        await _course(db, 'c1', 'Current', total: 90,
            classification: 'inprogress');
        await _course(db, 'c2', 'Old course', total: 70,
            classification: 'past');
      },
    );

    expect(find.text('Прошлые семестры'), findsOneWidget);
    expect(find.text('Old course'), findsNothing);
    // Overall GPA: (3.67*5 + 2.33*5) / 10 = 3.00.
    expect(find.text('Общий GPA 3.00'), findsOneWidget);

    await tester.tap(find.text('Прошлые семестры'));
    await tester.pumpAndSettle();
    expect(find.text('Old course'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('dark theme renders list and detail without exceptions',
      (tester) async {
    final db = await _pump(
      tester,
      theme: AppTheme.dark(),
      size: const Size(360, 740),
      seed: (db) async {
        await _course(db, 'c1', 'A very long course title that wraps nicely',
            midterm: 40, endterm: 45, classification: 'inprogress');
        await _course(db, 'c2', 'Physics', midterm: 95, endterm: 98,
            finalExam: 96, classification: 'inprogress');
        await _course(db, 'c3', 'No grades', classification: 'inprogress');
      },
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Риск отработки'), findsOneWidget);

    await tester.tap(find.text('Physics'));
    await _settle(tester);
    expect(find.byType(CourseDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _dispose(tester, db);
  });
}
