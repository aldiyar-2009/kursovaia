import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Handles one request: return the response body, or throw a
/// [DioException] to simulate a failure.
typedef FakeRoute = Object? Function(RequestOptions options);

/// API client whose requests never leave the process: [routes] maps
/// `"METHOD /path"` to a handler.
ApiClient fakeApi(Map<String, FakeRoute> routes, {List<String>? log}) {
  final api = ApiClient(baseUrl: 'http://test.local/api');
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final key = '${options.method} ${options.path}';
    log?.add(key);
    final route = routes[key];
    if (route == null) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    try {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: route(options),
      ));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }));
  return api;
}

DioException offline(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );

Widget wrapApp(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

Future<void> disposeWithDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  // Drift stream cleanup schedules a zero-duration timer.
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void usePhoneSize(WidgetTester tester, [Size size = const Size(360, 780)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
