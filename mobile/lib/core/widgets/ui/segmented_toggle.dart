import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Segmented control: a muted track with the selected segment raised as a
/// bordered surface.
///
/// With [expand] the segments share the available width equally (never
/// overflows on narrow phones, good for 2–4 short labels); without it the
/// control is as wide as its labels.
class SegmentedToggle<T> extends StatelessWidget {
  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;
  final double height;

  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = [
      for (final (v, label) in segments)
        _Segment(
          label: label,
          selected: v == value,
          expand: expand,
          onTap: () {
            if (v != value) onChanged(v);
          },
        ),
    ];
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final c in children) expand ? Expanded(child: c) : c],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.expand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // In dark mode `surface` is darker than the `surfaceMuted` track, so the
    // raised segment uses the lighter `border` tone to stay visible.
    final fill = dark ? p.border : p.surface;
    final outline = dark ? p.textTertiary.withValues(alpha: 0.4) : p.border;
    const radius = BorderRadius.all(Radius.circular(6));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 12),
            decoration: BoxDecoration(
              color: selected ? fill : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected ? outline : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(
                color: selected ? p.textPrimary : p.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
