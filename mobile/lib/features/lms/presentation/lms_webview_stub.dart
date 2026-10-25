import 'package:flutter/widgets.dart';

import 'lms_webview_common.dart';

/// The web build has no embedded browser that can run the import.
bool get isLmsImportSupported => false;

/// Placeholder with the same constructor as the io variant; never shown
/// because [isLmsImportSupported] is false.
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
