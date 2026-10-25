import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  DateTime Function() clock = DateTime.now,
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
    home: TasksScreen(db: db, userId: _user, group: group, clock: clock),
  ));
  await _settle(tester);
  return db;
}

/// A filter chip by its label (row labels like «LMS» use the same text).
Finder _chip(String label) => find.descendant(
      of: find.byKey(const ValueKey('tasks-filters')),
      matching: find.text(label),
    );

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

    await tester.tap(_chip('Группа'));
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
    await tester.ensureVisible(_chip('Выполненные'));
    await tester.pump();
    await tester.tap(_chip('Выполненные'));
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

  testWidgets('filter row scrolls and all 5 chips are reachable on a narrow phone',
      (tester) async {
    final db = await _pump(tester, size: const Size(320, 640));

    final filters = find.byKey(const ValueKey('tasks-filters'));
    final scrollable =
        find.descendant(of: filters, matching: find.byType(Scrollable));
    expect(scrollable, findsOneWidget);

    const labels = {
      'Все': 'Заданий нет',
      'Мои': 'Своих заданий нет',
      'Группа': 'Вы не состоите в группе',
      'LMS': 'Дедлайнов из LMS нет',
      'Выполненные': 'Выполненных заданий нет',
    };
    for (final MapEntry(key: label, value: empty) in labels.entries) {
      await tester.scrollUntilVisible(_chip(label), 40, scrollable: scrollable);
      await tester.pump();
      final rect = tester.getRect(_chip(label));
      expect(rect.left >= 0 && rect.right <= 320, isTrue, reason: label);
      await tester.tap(_chip(label));
      await _settle(tester);
      expect(find.text(empty), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('task sheet has a handle, a close button and a pinned save button',
      (tester) async {
    final db = await _pump(tester);
    await tester.tap(find.byTooltip('Новое задание'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-sheet-handle')), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);

    // Save is full width (sheet width minus the 16 px gutters).
    final save = find.byKey(const ValueKey('tasks-save'));
    expect(save, findsOneWidget);
    expect(tester.getSize(save).width, 400 - 32);

    // Title wraps to up to three lines.
    final title = tester.widget<TextField>(find.descendant(
      of: find.byKey(const ValueKey('tasks-title-field')),
      matching: find.byType(TextField),
    ));
    expect(title.minLines, 1);
    expect(title.maxLines, 3);

    // Priority uses the shared toggle; «Срок» has a chevron like «Предмет».
    expect(find.byKey(const ValueKey('tasks-priority')), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-sheet-handle')), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('subject picker marks the current subject and has 48 px rows',
      (tester) async {
    final db = await _pump(
      tester,
      seed: (db) async {
        await db.into(db.subjects).insert(SubjectsCompanion.insert(
              id: 's1',
              userId: _user,
              title: 'Физика',
              updatedAt: _ms(DateTime.now()),
            ));
      },
    );
    await tester.tap(find.byTooltip('Новое задание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Предмет'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    final none = find.byKey(const ValueKey('tasks-subject-none'));
    final physics = find.byKey(const ValueKey('tasks-subject-s1'));
    expect(tester.getSize(none).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(physics).height, greaterThanOrEqualTo(48));
    expect(find.descendant(of: none, matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.descendant(of: physics, matching: find.byIcon(Icons.check)), findsNothing);
    await tester.tap(physics);
    await tester.pumpAndSettle();
    expect(find.text('Физика'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('each task row is its own semantics node that opens details',
      (tester) async {
    final handle = tester.ensureSemantics();
    final now = DateTime(2026, 10, 26, 9, 30);
    final db = await _pump(
      tester,
      clock: () => now,
      seed: (db) => _insertTask(db,
          id: 't1', title: 'Lab report', due: DateTime(2026, 10, 27, 18)),
    );

    expect(find.text('Завтра, 18:00'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('task-open-t1'))),
      matchesSemantics(
        label: 'Lab report, срок: Завтра, 18:00, не выполнено',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('task-check-t1'))),
      matchesSemantics(
        label: 'Отметить выполненным, Lab report',
        isButton: true,
        hasCheckedState: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );

    // Activating the row node opens the task sheet.
    final node = tester.getSemantics(find.byKey(const ValueKey('task-open-t1')));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('Задание'), findsOneWidget);
    handle.dispose();
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
