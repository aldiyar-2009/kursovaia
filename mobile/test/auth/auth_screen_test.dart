import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

import '../group/group_test_utils.dart' show fakeApi;

Future<AppDatabase> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 900),
  ThemeData? theme,
  ApiClient? apiClient,
  VoidCallback? onLoginSuccess,
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
      home: AuthScreen(
        apiClient: apiClient ?? ApiClient(),
        db: db,
        settings: AppSettings(),
        onLoginSuccess: onLoginSuccess,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(db.close);
}

String _inviteText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('auth_invite')),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  testWidgets('sign-in shows no demo accounts and no prefilled values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester, size: const Size(360, 740));

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Настройки сервера'), findsOneWidget);
    for (final demo in ['headman', 'student@', 'password123', 'Демо', 'демо']) {
      expect(find.textContaining(demo), findsNothing);
    }
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(field.controller.text, isEmpty);
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('sign-up invite code is empty without a pending invite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester);

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Код группы (необязательно)'), findsOneWidget);
    expect(_inviteText(tester), isEmpty);
    expect(find.textContaining('IVT21A'), findsNothing);
    expect(find.textContaining('AITU26'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('sign-up invite code is prefilled from pending_invite_code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AuthScreen.pendingInviteKey: 'ABC123',
    });
    final db = await _pump(tester, theme: AppTheme.dark());

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(_inviteText(tester), 'ABC123');
    await _dispose(tester, db);
  });

  testWidgets('sign-up with an invite code resets the sync cursor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AuthScreen.pendingInviteKey: 'ABC123',
      kSyncCursorPrefsKey: 99999,
    });
    Map<String, dynamic>? body;
    final api = fakeApi({
      'POST /auth/register': (o) {
        body = o.data as Map<String, dynamic>;
        return {
          'token': 'jwt',
          'user': {'id': 'u9', 'name': 'New'},
          'group': {'id': 'g1', 'title': 'BDA-2601'},
        };
      },
    });
    var signedIn = false;
    final db = await _pump(
      tester,
      apiClient: api,
      onLoginSuccess: () => signedIn = true,
    );

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    Finder field(String key) => find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        );
    await tester.enterText(field('auth_name'), 'New');
    await tester.enterText(field('auth_email'), 'new@example.com');
    await tester.enterText(field('auth_password'), 'password123');
    await tester.enterText(field('auth_confirm'), 'password123');
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(signedIn, isTrue);
    expect(body?['invite_code'], 'ABC123');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kSyncCursorPrefsKey), 0);
    expect(prefs.getString(AuthScreen.pendingInviteKey), isNull);
    await _dispose(tester, db);
  });

  testWidgets('mode switch is the core segmented toggle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester);

    expect(find.byWidgetPredicate((w) => w is SegmentedButton), findsNothing);
    final toggle = find.byKey(const ValueKey('auth_mode'));
    expect(toggle, findsOneWidget);
    expect(tester.widget(toggle), isA<SegmentedToggle<Object?>>());
    // Stretched to the form width.
    expect(
      tester.getSize(toggle).width,
      tester.getSize(find.byType(Form)).width,
    );
    await _dispose(tester, db);
  });

  testWidgets('confirm password has its own visibility toggle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester);

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    bool obscured(String key) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    final toggle = find.byKey(const ValueKey('auth_confirm_visibility'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('auth_confirm')),
        matching: toggle,
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Показать повтор пароля'), findsOneWidget);
    expect(obscured('auth_confirm'), isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(obscured('auth_confirm'), isFalse);
    expect(obscured('auth_password'), isTrue);
    expect(find.byTooltip('Скрыть повтор пароля'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('empty submit shows inline validation errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester, size: const Size(1280, 800));

    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    // The form stays narrow on wide windows.
    final width = tester.getSize(find.byType(Form)).width;
    expect(width, lessThanOrEqualTo(400));
    await _dispose(tester, db);
  });
}
