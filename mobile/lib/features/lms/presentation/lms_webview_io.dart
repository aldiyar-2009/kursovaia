import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../data/moodle_page_script.dart';
import 'lms_webview_common.dart';

/// The embedded browser exists on Android, iOS and Windows (WebView2).
bool get isLmsImportSupported =>
    Platform.isAndroid || Platform.isIOS || Platform.isWindows;

/// Hosts whose cookies make up the LMS sign-in of the embedded browser.
const _sessionHosts = [kLmsHost, 'login.microsoftonline.com'];

/// Forgets the LMS / Microsoft sign-in of the embedded browser (called on
/// logout of the app): deletes the cookies of [_sessionHosts] and, where the
/// platform allows it, the web storage of those origins. Other sites are not
/// touched. Never throws; a platform without an API simply skips that step.
Future<void> clearLmsWebSession() async {
  final cookies = CookieManager.instance();
  for (final host in _sessionHosts) {
    try {
      await cookies.deleteCookies(url: WebUri('https://$host'));
    } catch (_) {}
    try {
      // Cookies set for the parent domain (e.g. `.astanait.edu.kz`) too.
      await cookies.deleteCookies(url: WebUri('https://$host'), domain: host);
    } catch (_) {}
  }
  try {
    final storage = WebStorageManager.instance();
    if (Platform.isAndroid) {
      for (final host in _sessionHosts) {
        await storage.deleteOrigin(origin: 'https://$host');
      }
    } else if (Platform.isIOS) {
      final records = await storage.fetchDataRecords(
        dataTypes: WebsiteDataType.ALL,
      );
      // WebKit groups records by registrable domain (`astanait.edu.kz`).
      final mine = records.where((r) {
        final name = r.displayName ?? '';
        return name.isNotEmpty && _sessionHosts.any((h) => h.endsWith(name));
      }).toList();
      if (mine.isNotEmpty) {
        await storage.removeDataFor(
          dataTypes: WebsiteDataType.ALL,
          dataRecords: mine,
        );
      }
    }
  } catch (_) {}
}

/// Embedded browser for the Microsoft sign-in and the in-page import.
///
/// The app never touches the login form, never reads cookies and never
/// reads page HTML from Dart: the only data that leaves the page is the
/// JSON string returned by [kMoodleImportScript].
class LmsWebView extends StatelessWidget {
  const LmsWebView({
    super.key,
    required this.initialUrl,
    required this.onCreated,
    required this.onLoadStop,
    this.onUrlChanged,
    this.onProgress,
  });

  final Uri initialUrl;
  final void Function(LmsWebViewController controller) onCreated;
  final void Function(Uri? url) onLoadStop;
  final void Function(Uri? url)? onUrlChanged;
  final void Function(int progress)? onProgress;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
      ),
      onWebViewCreated: (c) => onCreated(_InAppController(c)),
      onLoadStart: (_, url) => onUrlChanged?.call(url),
      onUpdateVisitedHistory: (_, url, _) => onUrlChanged?.call(url),
      onProgressChanged: (_, progress) => onProgress?.call(progress),
      onLoadStop: (_, url) {
        onUrlChanged?.call(url);
        onLoadStop(url);
      },
    );
  }
}

class _InAppController implements LmsWebViewController {
  _InAppController(this._c);

  final InAppWebViewController _c;

  @override
  Future<bool> hasSesskey() async {
    try {
      final v = await _c.evaluateJavascript(source: kLmsSesskeyCheck);
      return v == true || v == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> runImport({
    required int sinceSec,
    required int untilSec,
  }) async {
    final r = await _c.callAsyncJavaScript(
      functionBody: '$kMoodleImportScript\n$kMoodleImportInvocation',
      arguments: {'sinceSec': sinceSec, 'untilSec': untilSec},
    );
    if (r == null) throw const LmsScriptException('no result');
    final error = r.error;
    if (error != null) throw LmsScriptException(error);
    final value = r.value;
    if (value is String) return value;
    if (value is Map) return jsonEncode(value);
    throw const LmsScriptException('unexpected result');
  }
}
