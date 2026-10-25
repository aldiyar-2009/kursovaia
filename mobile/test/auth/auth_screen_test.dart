import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

Future<AppDatabase> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 900),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
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
    home: AuthScreen(apiClient: ApiClient(), db: db, settings: AppSettings()),
  ));
  await tester.pumpAndSettle();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(db.close);
}

String _inviteText(WidgetTester tester) => tester
    .widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('auth_invite')),
      matching: find.byType(EditableText),
    ))
    .controller
    .text;

void main() {
  testWidgets('sign-in shows no demo accounts and no prefilled values',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await _pump(tester, size: const Size(360, 740));

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Настройки сервера'), findsOneWidget);
    for (final demo in ['headman', 'student@', 'password123', 'Демо', 'демо']) {
      expect(find.textContaining(demo), findsNothing);
    }
    for (final field in tester.widgetList<EditableText>(find.byType(EditableText))) {
      expect(field.controller.text, isEmpty);
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('sign-up invite code is empty without a pending invite',
      (tester) async {
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

  testWidgets('sign-up invite code is prefilled from pending_invite_code',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthScreen.pendingInviteKey: 'ABC123',
    });
    final db = await _pump(tester, theme: AppTheme.dark());

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(_inviteText(tester), 'ABC123');
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
