import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Maximum width of a bottom sheet on wide screens (centred).
const double kSheetMaxWidth = 640;

/// Height of the full-width primary button pinned at the bottom of a sheet.
const double kPrimaryButtonHeight = 48;

/// Shows the app's standard bottom sheet: drag handle, [title] with a close
/// button, a scrollable body from [builder] that stays above the keyboard,
/// and an optional full-width [primaryAction] pinned at the bottom.
///
/// [builder] must return non-scrollable content (a `Column`, a form): it is
/// already placed inside a `SingleChildScrollView` with 16 px side padding.
/// [primaryAction] is usually a `FilledButton`; it is stretched to the full
/// width and given a height of [kPrimaryButtonHeight]. If it depends on the
/// body's state, use [showAppSheetCustom] with an [AppSheetLayout] instead.
///
/// The sheet pops with `null` on close; pop with a value from the body or
/// the action to return a result.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
  Widget? primaryAction,
}) {
  return showAppSheetCustom<T>(
    context,
    builder: (sheetContext) => AppSheetLayout(
      title: title,
      primaryAction: primaryAction,
      body: Builder(builder: builder),
    ),
  );
}

/// Opens [builder] in the standard sheet chrome (surface colour, radius 12
/// on top, no shadow, max width [kSheetMaxWidth], safe area, scroll
/// controlled). [builder] should return an [AppSheetLayout], typically from
/// a `StatefulWidget` that owns the form state and its primary button.
Future<T?> showAppSheetCustom<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final p = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: p.surface,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
    builder: builder,
  );
}

/// Layout of a standard sheet; use directly inside [showAppSheetCustom].
class AppSheetLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? primaryAction;

  /// Defaults to `Navigator.pop(context)`.
  final VoidCallback? onClose;

  const AppSheetLayout({
    super.key,
    required this.title,
    required this.body,
    this.primaryAction,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final action = primaryAction;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                key: const ValueKey('app-sheet-handle'),
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: context.text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: p.textSecondary,
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  action == null ? 24 : 16,
                ),
                child: body,
              ),
            ),
            if (action != null) ...[
              Divider(height: 1, color: p.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButtonTheme(
                  data: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(kPrimaryButtonHeight),
                    ).merge(theme.filledButtonTheme.style),
                  ),
                  child: SizedBox(width: double.infinity, child: action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
