import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// One bar of [BarList] / [ColumnChart].
class ChartBar {
  final String label;
  final double value;

  /// Text shown next to / above the bar; defaults to [value] rounded.
  final String? valueText;

  /// Bar colour; the accent by default.
  final Color? color;

  const ChartBar(this.label, this.value, {this.valueText, this.color});
}

/// Horizontal bars, one per row: label on the left, value on the right.
/// Used for per-subject averages and distributions.
class BarList extends StatelessWidget {
  final List<ChartBar> bars;

  /// Value of a full-width bar; the largest value by default.
  final double? max;

  const BarList({super.key, required this.bars, this.max});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top =
        max ?? bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    return Column(
      children: [
        for (final b in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    b.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final share = top <= 0
                          ? 0.0
                          : (b.value / top).clamp(0.0, 1.0);
                      return Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 8,
                            width: c.maxWidth * share,
                            decoration: BoxDecoration(
                              color: b.color ?? p.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    b.valueText ?? b.value.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: context.text.labelMedium!.tabular,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical columns (e.g. average per month) with the value above each one.
class ColumnChart extends StatelessWidget {
  final List<ChartBar> bars;
  final double max;
  final double height;

  const ColumnChart({
    super.key,
    required this.bars,
    required this.max,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      b.valueText ?? b.value.toStringAsFixed(0),
                      style: context.text.labelSmall!.tabular,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: max <= 0
                          ? 0
                          : height * (b.value / max).clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: b.color ?? p.accent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md / 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Figures side by side in one bordered strip (like the grades summary).
class StatStrip extends StatelessWidget {
  final List<(String label, String value)> items;

  const StatStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(const VerticalDivider(width: 1));
      final (label, value) = items[i];
      children.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(value, style: context.text.titleLarge!.tabular),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Bordered surface block with an optional title, for charts.
class ChartCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const ChartCard({super.key, this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title!, style: context.text.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: context.text.bodySmall),
          ],
          if (title != null || subtitle != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
