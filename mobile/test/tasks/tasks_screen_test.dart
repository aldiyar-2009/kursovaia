import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/features/tasks/domain/task_list_item.dart';
import 'package:studyplan/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

const _user = 'u1';

Future<AppDatabase> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? group,
  ThemeData? theme,
  Size size = const Size(400, 800),
  Future<void> Function(AppDatabase db)? seed,
}) async {
  SharedPreferences.setMockInitialValues({});
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
    home: TasksScreen(db: db, userId: _user, group: group),
  ));
  await _settle(tester);
  return db;
}

/// Lets drift streams emit (real async), then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

BigInt _ms(DateTime d) => BigInt.from(d.millisecondsSinceEpoch);

Future<void> _insertTask(
  AppDatabase db, {
  required String id,
  required String title,
  DateTime? due,
  String userId = _user,
  bool isGroup = false,
  String? groupId,
  int priority = 3,
  String? subject,
}) {
  return db.into(db.tasks).insert(TasksCompanion.insert(
        id: id,
        userId: userId,
        title: title,
        dueDate: Value(due == null ? null : _ms(due)),
        isGroup: Value(isGroup),
        groupId: Value(groupId),
        priority: Value(priority),
        subjectTitle: Value(subject),
        updatedAt: _ms(DateTime.now()),
      ));
}

Future<void> _insertLmsDeadline(
  AppDatabase db, {
  required String id,
  required String title,
  required DateTime due,
  String? url,
}) {
  return db.into(db.lmsEvents).insert(LmsEventsCompanion.insert(
        id: id,
        userId: _user,
        title: title,
        courseTitle: const Value('Algorithms'),
        eventType: const Value('deadline'),
        startsAt: _ms(due),
        url: Value(url),
        updatedAt: _ms(DateTime.now()),
      ));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('empty database shows the empty state with a create action', (tester) async {
    final db = await _pump(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Заданий нет'), findsOneWidget);
    expect(find.text('Новое задание'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('filter «Группа» without a group explains how to join', (tester) async {
    final db = await _pump(tester, group: null);

    await tester.tap(find.byKey(const ValueKey('tasks-filter-group')));
    await _settle(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Вы не состоите в группе'), findsOneWidget);
    expect(find.textContaining('вступите по коду'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('LMS deadline is labelled and its done toggle persists', (tester) async {
    final due = DateTime.now().add(const Duration(days: 3));
    final db = await _pump(
      tester,
      seed: (db) => _insertLmsDeadline(db, id: 'e1', title: 'Quiz 2', due: due),
    );

    expect(find.text('Quiz 2'), findsOneWidget);
    expect(find.text('LMS'), findsWidgets); // filter chip + row label

    await tester.tap(find.byKey(const ValueKey('task-check-e1')));
    await _settle(tester);

    final row = await tester.runAsync(() =>
        (db.select(db.lmsEvents)..where((t) => t.id.equals('e1'))).getSingle());
    expect(row!.isDone, isTrue);
    expect(row.syncStatus, 'pending_update');

    // Done items leave the active list and appear under «Выполненные».
    expect(find.text('Quiz 2'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('tasks-filter-done')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tasks-filter-done')));
    await _settle(tester);
    expect(find.text('Quiz 2'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('overdue task appears under «Просрочено»', (tester) async {
    final now = DateTime.now();
    final db = await _pump(
      tester,
      seed: (db) async {
        await _insertTask(db,
            id: 't1', title: 'Lab report', due: now.subtract(const Duration(days: 1)));
        await _insertTask(db, id: 't2', title: 'Read chapter 4');
      },
    );

    expect(find.text('Просрочено'), findsOneWidget);
    expect(find.text('Без срока'), findsOneWidget);
    final header = tester.getTopLeft(find.text('Просрочено')).dy;
    final overdue = tester.getTopLeft(find.text('Lab report')).dy;
    final noDateHeader = tester.getTopLeft(find.text('Без срока')).dy;
    expect(header < overdue && overdue < noDateHeader, isTrue);
    await _dispose(tester, db);
  });

  testWidgets('group publish switch appears only when the user has a group', (tester) async {
    var db = await _pump(tester);
    await tester.tap(find.byTooltip('Новое задание'));
    await tester.pumpAndSettle();
    expect(find.text('Название'), findsOneWidget);
    expect(find.byKey(const ValueKey('tasks-publish-group')), findsNothing);
    await _dispose(tester, db);

    db = await _pump(tester, group: const {'id': 'g1', 'title': 'BDA-2601'});
    await tester.tap(find.byTooltip('Новое задание'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tasks-publish-group')), findsOneWidget);
    expect(find.text('Опубликовать для группы'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('group task of another member shows label, author and is read-only',
      (tester) async {
    final db = await _pump(
      tester,
      group: const {
        'id': 'g1',
        'title': 'BDA-2601',
        'members': [
          {'id': 'u2', 'name': 'Aigerim'},
        ],
      },
      seed: (db) => _insertTask(db,
          id: 'g-task', title: 'Group essay', userId: 'u2', isGroup: true, groupId: 'g1'),
    );

    expect(find.text('Group essay'), findsOneWidget);
    expect(find.text('Автор: Aigerim'), findsOneWidget);
    final check = find.byKey(const ValueKey('task-check-g-task'));
    expect(find.descendant(of: check, matching: find.byType(IconButton)), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('dark theme at 360 px with long content has no overflow', (tester) async {
    final now = DateTime.now();
    final long = 'Очень длинное название задания, которое не помещается в одну строку ' * 2;
    final db = await _pump(
      tester,
      theme: AppTheme.dark(),
      size: const Size(360, 720),
      group: const {'id': 'g1', 'title': 'BDA-2601'},
      seed: (db) async {
        await _insertTask(db,
            id: 'a',
            title: long,
            due: now.add(const Duration(hours: 1)),
            priority: 1,
            subject: 'Объектно-ориентированное программирование и проектирование');
        await _insertTask(db,
            id: 'b',
            title: 'Group',
            isGroup: true,
            groupId: 'g1',
            due: now.add(const Duration(days: 20)));
        await _insertLmsDeadline(db,
            id: 'e', title: long, due: now.add(const Duration(days: 2)), url: 'https://x');
      },
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Новое задание'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  test('bucketFor splits by due date', () {
    final now = DateTime(2026, 10, 26, 12);
    expect(bucketFor(null, now), TaskBucket.noDate);
    expect(bucketFor(DateTime(2026, 10, 26, 11), now), TaskBucket.overdue);
    expect(bucketFor(DateTime(2026, 10, 26, 23, 59), now), TaskBucket.today);
    expect(bucketFor(DateTime(2026, 10, 27, 9), now), TaskBucket.week);
    expect(bucketFor(DateTime(2026, 11, 2, 23), now), TaskBucket.week);
    expect(bucketFor(DateTime(2026, 11, 3, 0), now), TaskBucket.later);
  });
}
