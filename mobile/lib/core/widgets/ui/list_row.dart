import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// A single list row: 56 px tall (64 with a subtitle), 16 px side padding.
/// Transparent — place it inside a [ListGroup] or on a surface.
class ListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Colour override for the title, e.g. `palette.danger` for "Выйти".
  final Color? titleColor;

  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: palette.textSecondary, size: 22),
                child: leading!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium!.copyWith(
                      color: titleColor ?? palette.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              DefaultTextStyle.merge(
                style: context.text.bodyMedium!
                    .copyWith(color: palette.textSecondary)
                    .tabular,
                child: IconTheme.merge(
                  data: IconThemeData(color: palette.textTertiary, size: 20),
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Trailing chevron for rows that open another screen.
class ListRowChevron extends StatelessWidget {
  const ListRowChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, color: context.palette.textTertiary, size: 20);
}

/// Groups rows on a surface with a 1 px border and inset dividers,
/// like a settings section.
class ListGroup extends StatelessWidget {
  final List<Widget> children;

  /// Left inset of dividers; 16 aligns them with row text.
  final double dividerIndent;

  const ListGroup({
    super.key,
    required this.children,
    this.dividerIndent = 16,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, indent: dividerIndent));
      }
      items.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}
