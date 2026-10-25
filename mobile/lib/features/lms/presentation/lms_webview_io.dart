import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../data/moodle_page_script.dart';
import 'lms_webview_common.dart';

/// The embedded browser exists on Android, iOS and Windows (WebView2).
bool get isLmsImportSupported =>
    Platform.isAndroid || Platform.isIOS || Platform.isWindows;

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
