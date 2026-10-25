import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/group/data/group_repository.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';

import 'group_test_utils.dart';

const _group = {
  'id': 'g1',
  'title': 'BDA-2601',
  'invite_code': 'ABC123',
  'semester': 1,
  'semester_start': null,
};

const _members = [
  {'id': 'u1', 'name': 'Айгерим Садыкова'},
  {'id': 'u2', 'name': 'Данияр Ахметов'},
];

void main() {
  group('GroupRepository', () {
    test('invite link drops the /api suffix and trailing slashes', () {
      expect(
        GroupRepository.inviteLink('http://host:3000/api/', 'ABC123'),
        'http://host:3000/join/ABC123',
      );
      expect(
        GroupRepository.inviteLink('https://studyplan.dev', 'X1'),
        'https://studyplan.dev/join/X1',
      );
    });

    test(
      'stores and takes the pending invite code from a /join path',
      () async {
        SharedPreferences.setMockInitialValues({});
        await GroupRepository.storePendingInviteFromPath('/tasks');
        expect(await GroupRepository.takePendingInviteCode(), isNull);

        await GroupRepository.storePendingInviteFromPath('/join/abc123');
        expect(await GroupRepository.takePendingInviteCode(), 'ABC123');
        expect(await GroupRepository.takePendingInviteCode(), isNull);
      },
    );
  });

  testWidgets('no group shows the empty state with join and create', (
    tester,
  ) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final api = fakeApi({
      'GET /groups/me': (_) => {'group': null, 'members': <Object>[]},
    });

    await tester.pumpWidget(
      wrapApp(GroupScreen(db: db, apiClient: api, userId: 'u1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вы не в группе'), findsOneWidget);
    expect(find.text('Вступить по коду'), findsOneWidget);
    expect(find.text('Создать группу'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeWithDb(tester, db);
  });

  testWidgets('pending invite code prefills the join form and is cleared', (
    tester,
  ) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({'pending_invite_code': 'XYZ789'});
    final db = AppDatabase(NativeDatabase.memory());
    final api = fakeApi({
      'GET /groups/me': (_) => {'group': null, 'members': <Object>[]},
    });

    await tester.pumpWidget(
      wrapApp(GroupScreen(db: db, apiClient: api, userId: 'u1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вступить в группу'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'XYZ789'), findsOneWidget);
    // Standard sheet chrome: handle, close button, pinned primary action.
    expect(find.byKey(const ValueKey('app-sheet-handle')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(AppSheetLayout), findsOneWidget);
    final sheetWidth = tester.getSize(find.byType(AppSheetLayout)).width;
    final button = find.widgetWithText(FilledButton, 'Вступить');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, sheetWidth - 32);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_invite_code'), isNull);

    await disposeWithDb(tester, db);
  });

  for (final dark in [false, true]) {
    testWidgets('group shows code and members, invite text has the link '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      usePhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      final api = fakeApi({
        'GET /groups/me': (_) => {'group': _group, 'members': _members},
      });
      String? shared;
      Map<String, dynamic>? changed;

      await tester.pumpWidget(
        wrapApp(
          GroupScreen(
            db: db,
            apiClient: api,
            userId: 'u1',
            group: Map<String, dynamic>.from(_group),
            onGroupChanged: (g) => changed = g,
            onShare: (text, _) async => shared = text,
          ),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BDA-2601'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Айгерим Садыкова'), findsOneWidget);
      expect(find.text('Данияр Ахметов'), findsOneWidget);
      expect(find.text('вы'), findsOneWidget);
      expect(find.text('2 участника'), findsOneWidget);
      expect(find.text('Материалы группы'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Same group as the caller already had: no change reported.
      expect(changed, isNull);

      await tester.tap(find.text('Пригласить'));
      await tester.pump();
      expect(shared, contains('BDA-2601'));
      expect(shared, contains('ABC123'));
      expect(shared, contains('http://test.local/join/ABC123'));

      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('group_data')!) as Map<String, dynamic>;
      expect(saved['invite_code'], 'ABC123');

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Покинуть группу').hitTestable(), findsOneWidget);

      await disposeWithDb(tester, db);
    });
  }

  testWidgets('invite falls back to the clipboard when sharing fails', (
    tester,
  ) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final api = fakeApi({
      'GET /groups/me': (_) => {'group': _group, 'members': _members},
    });
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var attempts = 0;

    await tester.pumpWidget(
      wrapApp(
        GroupScreen(
          db: db,
          apiClient: api,
          userId: 'u1',
          group: Map<String, dynamic>.from(_group),
          // Same path as the web build or a platform without a share sheet.
          onShare: (_, _) async {
            attempts++;
            throw UnsupportedError('no share sheet');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пригласить'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(clipboard, contains('BDA-2601'));
    expect(clipboard, contains('ABC123'));
    expect(clipboard, contains('http://test.local/join/ABC123'));
    expect(find.text('Текст приглашения скопирован'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeWithDb(tester, db);
  });

  testWidgets('group content stays in a 720 px column on wide screens', (
    tester,
  ) async {
    usePhoneSize(tester, const Size(1280, 900));
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final api = fakeApi({
      'GET /groups/me': (_) => {'group': _group, 'members': _members},
    });

    await tester.pumpWidget(
      wrapApp(
        GroupScreen(
          db: db,
          apiClient: api,
          userId: 'u1',
          group: Map<String, dynamic>.from(_group),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('Материалы группы'),
      matching: find.byType(ListGroup),
    );
    expect(tester.getSize(row).width, lessThanOrEqualTo(720));
    expect(tester.getTopLeft(row).dx, (1280 - 720) / 2);

    await disposeWithDb(tester, db);
  });

  testWidgets('leaving after confirmation clears group_data', (tester) async {
    usePhoneSize(tester, const Size(400, 1200));
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    var inGroup = true;
    final api = fakeApi({
      'GET /groups/me': (_) => inGroup
          ? {'group': _group, 'members': _members}
          : {'group': null, 'members': <Object>[]},
      'POST /groups/leave': (_) {
        inGroup = false;
        return {'token': 't', 'user': {}, 'group': null};
      },
    });
    var changedToNull = false;

    await tester.pumpWidget(
      wrapApp(
        GroupScreen(
          db: db,
          apiClient: api,
          userId: 'u1',
          group: Map<String, dynamic>.from(_group),
          onGroupChanged: (g) => changedToNull = g == null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покинуть группу'));
    await tester.pumpAndSettle();
    expect(find.text('Покинуть группу?'), findsOneWidget);
    await tester.tap(find.text('Покинуть'));
    await tester.pumpAndSettle();

    expect(find.text('Вы не в группе'), findsOneWidget);
    expect(changedToNull, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('group_data'), isNull);

    await disposeWithDb(tester, db);
  });
}
