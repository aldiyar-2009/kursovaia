import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Strip above every tab while the app runs without a real account: guest
/// mode offers sign-in and demo mode, demo mode reminds that the data is
/// sample data.
class AccountBanner extends StatelessWidget {
  final String title;
  final String? message;

  /// Primary and secondary actions; omitted when null.
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows a spinner instead of the primary button (demo account requested).
  final bool busy;

  const AccountBanner({
    super.key,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final buttonStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      minimumSize: const WidgetStatePropertyAll(Size(44, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: WidgetStatePropertyAll(context.text.labelMedium),
    );
    return Material(
      color: p.warningMuted,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              spacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.labelLarge),
                      if (message != null)
                        Text(
                          message!,
                          style: context.text.bodySmall!.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (secondaryLabel != null && onSecondary != null)
                      TextButton(
                        key: const ValueKey('account_banner_secondary'),
                        style: buttonStyle.copyWith(
                          foregroundColor: WidgetStatePropertyAll(
                            p.textPrimary,
                          ),
                        ),
                        onPressed: busy ? null : onSecondary,
                        child: Text(secondaryLabel!),
                      ),
                    if (primaryLabel != null && onPrimary != null)
                      busy
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : FilledButton(
                              key: const ValueKey('account_banner_primary'),
                              style: buttonStyle,
                              onPressed: onPrimary,
                              child: Text(primaryLabel!),
                            ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
