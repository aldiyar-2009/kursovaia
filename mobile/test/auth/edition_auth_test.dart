import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/features/auth/presentation/account_actions.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/auth/presentation/screens/edition_choice_screen.dart';

import '../group/group_test_utils.dart' show fakeApi, wrapApp;

void main() {
  testWidgets('edition choice saves the edition and opens the college sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final settings = AppSettings();
    await tester.pumpWidget(wrapApp(EditionChoiceScreen(
      deps: AppDeps(db: db, apiClient: ApiClient(), settings: settings),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Студент университета'), findsOneWidget);
    expect(find.text('Студент колледжа'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edition_college')));
    await tester.pumpAndSettle();

    expect(settings.edition, AppEdition.college);
    expect(find.text('Вход через SmartNation'), findsOneWidget);
    expect(find.text('ИИН или логин'), findsOneWidget);
    // No email registration for the college.
    expect(find.text('Регистрация'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('college sign-in posts the SmartNation login and shows its errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final sent = <Object?>[];
    final api = fakeApi({
      'POST /auth/smartnation': (options) {
        sent.add(options.data);
        throw snInvalid(options);
      },
    });
    await tester.pumpWidget(wrapApp(AuthScreen(
      apiClient: api,
      db: db,
      settings: AppSettings(),
      edition: AppEdition.college,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('auth_email')), matching: find.byType(EditableText)),
      '010203040506',
    );
    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('auth_password')), matching: find.byType(EditableText)),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit')));
    await tester.pumpAndSettle();

    expect(sent.single, {'login': '010203040506', 'password': 'secret'});
    expect(find.text('Неверный логин или пароль SmartNation'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}

/// 401 with the SmartNation error code, as the server sends it.
DioException snInvalid(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 401,
        data: {
          'error': {'code': 'SN_INVALID_CREDENTIALS', 'message': 'Wrong login'},
        },
      ),
    );
