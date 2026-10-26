import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/connect_link.dart';

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

  test('apply saves the base URL and updates the client', () async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(baseUrl: 'http://127.0.0.1:3000/api');
    final ok = await ConnectLinkService(apiClient: client).apply(
      'studyplan://connect?server=http%3A%2F%2F10.0.0.5%3A3000',
    );
    expect(ok, isTrue);
    expect(client.dio.options.baseUrl, 'http://10.0.0.5:3000/api');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kApiBaseUrlPrefsKey), 'http://10.0.0.5:3000/api');
  });
}
