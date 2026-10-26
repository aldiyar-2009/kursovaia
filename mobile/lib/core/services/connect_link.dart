import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';

/// SharedPreferences key of the API base URL (also written by the server
/// settings dialog and read by the splash screen).
const kApiBaseUrlPrefsKey = 'api_base_url';

/// API base URL (`<server>/api`) from a `studyplan://connect?server=<origin>`
/// link, or null when the link is not a valid connect link.
String? apiBaseUrlFromConnectLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || uri.scheme != 'studyplan' || uri.host != 'connect') {
    return null;
  }
  final server = Uri.tryParse(uri.queryParameters['server'] ?? '');
  if (server == null ||
      (server.scheme != 'http' && server.scheme != 'https') ||
      server.host.isEmpty) {
    return null;
  }
  return '${server.origin}/api';
}

/// Receives connect links from the server's startup QR code (Android only;
/// see `MainActivity.kt`) and saves the server address, so the app is set up
/// without typing the laptop's IP.
class ConnectLinkService {
  static const _channel = MethodChannel('studyplan/connect_link');

  final ApiClient apiClient;

  /// Called after a link that arrived while the app was running is applied.
  final VoidCallback? onApplied;

  ConnectLinkService({required this.apiClient, this.onApplied});

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Applies the link the app was launched with (before the splash screen
  /// reads the saved address) and listens for later ones.
  Future<void> start() async {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        if (await apply(call.arguments as String)) onApplied?.call();
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null) await apply(initial);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  /// Saves the server from [link]; false when the link is not a connect link.
  Future<bool> apply(String link) async {
    final baseUrl = apiBaseUrlFromConnectLink(link);
    if (baseUrl == null) return false;
    apiClient.updateBaseUrl(baseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kApiBaseUrlPrefsKey, baseUrl);
    return true;
  }
}
