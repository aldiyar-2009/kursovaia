import 'package:flutter/material.dart';
import 'package:studyplan/core/services/connect_link.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Wraps the app (`MaterialApp.builder`) and asks to confirm the server from a
/// connect link before it is saved. Drawn above the navigator, so it does not
/// depend on which route (splash, auth, shell) is showing.
class ConnectLinkPrompt extends StatelessWidget {
  final ConnectLinkService service;
  final Widget child;

  const ConnectLinkPrompt({
    super.key,
    required this.service,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: service.pending,
      child: child,
      builder: (context, baseUrl, child) {
        if (baseUrl == null) return child!;
        final l10n = context.l10n;
        final host = Uri.parse(baseUrl).authority;
        return Stack(
          children: [
            child!,
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            Center(
              child: AlertDialog(
                key: const ValueKey('connect_link_prompt'),
                title: Text(l10n.connect_title),
                content: Text(l10n.connect_body(host)),
                actions: [
                  TextButton(
                    onPressed: service.dismiss,
                    child: Text(l10n.common_cancel),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await service.confirm();
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text(l10n.profile_serverSaved)),
                      );
                    },
                    child: Text(l10n.connect_confirm),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
