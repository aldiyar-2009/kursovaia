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
/// see `MainActivity.kt`). Any page can open such a link, so a link is never
/// applied on its own: it becomes [pending] and is saved only after the user
/// confirms the shown address ([confirm]), see `ConnectLinkPrompt`.
class ConnectLinkService {
  static const _channel = MethodChannel('studyplan/connect_link');

  final ApiClient apiClient;

  /// Base URL from the last link, waiting for confirmation.
  final ValueNotifier<String?> pending = ValueNotifier(null);

  ConnectLinkService({required this.apiClient});

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Picks up the link the app was launched with and listens for later ones.
  Future<void> start() async {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        receive(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null) receive(initial);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  /// Queues [link] for confirmation; false when it is not a connect link or
  /// points at the server already in use.
  bool receive(String link) {
    final baseUrl = apiBaseUrlFromConnectLink(link);
    if (baseUrl == null || baseUrl == apiClient.dio.options.baseUrl) {
      return false;
    }
    pending.value = baseUrl;
    return true;
  }

  /// Saves the pending server as the API address.
  Future<void> confirm() async {
    final baseUrl = pending.value;
    if (baseUrl == null) return;
    pending.value = null;
    apiClient.updateBaseUrl(baseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kApiBaseUrlPrefsKey, baseUrl);
  }

  void dismiss() => pending.value = null;
}
