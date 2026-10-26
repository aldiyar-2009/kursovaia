import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/connect_link.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/connect_link_prompt.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

const _link = 'studyplan://connect?server=http%3A%2F%2F10.0.0.5%3A3000';

void main() {
  group('apiBaseUrlFromConnectLink', () {
    test('builds <server>/api from the server origin', () {
      expect(
        apiBaseUrlFromConnectLink(
          'studyplan://connect?server=http%3A%2F%2F192.168.0.10%3A3000',
        ),
        'http://192.168.0.10:3000/api',
      );
    });

    test('drops any path from the server value', () {
      expect(
        apiBaseUrlFromConnectLink(
          'studyplan://connect?server=https%3A%2F%2Fexample.com%2Fopen',
        ),
        'https://example.com/api',
      );
    });

    test('rejects other links and non-http servers', () {
      expect(apiBaseUrlFromConnectLink('https://example.com'), isNull);
      expect(apiBaseUrlFromConnectLink('studyplan://other?server=http://a'),
          isNull);
      expect(apiBaseUrlFromConnectLink('studyplan://connect'), isNull);
      expect(
          apiBaseUrlFromConnectLink(
              'studyplan://connect?server=javascript%3Aalert(1)'),
          isNull);
    });
  });

  group('ConnectLinkService', () {
    late ApiClient client;
    late ConnectLinkService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      client = ApiClient(baseUrl: 'http://127.0.0.1:3000/api');
      service = ConnectLinkService(apiClient: client);
    });

    test('a received link waits for confirmation and changes nothing', () async {
      expect(service.receive(_link), isTrue);
      expect(service.pending.value, 'http://10.0.0.5:3000/api');
      expect(client.dio.options.baseUrl, 'http://127.0.0.1:3000/api');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kApiBaseUrlPrefsKey), isNull);
    });

    test('confirm saves the base URL and updates the client', () async {
      service.receive(_link);
      await service.confirm();
      expect(service.pending.value, isNull);
      expect(client.dio.options.baseUrl, 'http://10.0.0.5:3000/api');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kApiBaseUrlPrefsKey), 'http://10.0.0.5:3000/api');
    });

    test('dismiss drops the link', () async {
      service.receive(_link);
      service.dismiss();
      expect(service.pending.value, isNull);
      expect(client.dio.options.baseUrl, 'http://127.0.0.1:3000/api');
    });

    test('a link to the current server is ignored', () {
      client.updateBaseUrl('http://10.0.0.5:3000/api');
      expect(service.receive(_link), isFalse);
      expect(service.pending.value, isNull);
    });
  });

  testWidgets('prompt shows the host and saves only after Connect',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(baseUrl: 'http://127.0.0.1:3000/api');
    final service = ConnectLinkService(apiClient: client);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          ConnectLinkPrompt(service: service, child: child!),
      home: const Scaffold(body: Text('home')),
    ));
    expect(find.byKey(const ValueKey('connect_link_prompt')), findsNothing);

    service.receive(_link);
    await tester.pump();
    expect(find.byKey(const ValueKey('connect_link_prompt')), findsOneWidget);
    expect(find.textContaining('10.0.0.5:3000'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connect_link_prompt')), findsNothing);
    expect(client.dio.options.baseUrl, 'http://10.0.0.5:3000/api');
  });
}
