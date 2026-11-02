import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the browser; a snackbar explains when it cannot be opened.
Future<void> openExternalUrl(BuildContext context, String? url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.tasks_linkFailed;
  final uri = url == null ? null : Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
}
