import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Equal-width segmented control: a muted track with the selected segment
/// raised as a bordered surface. Segments share the width, so it never
/// overflows on narrow phones.
class SegmentedToggle<T> extends StatelessWidget {
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: _Segment(
                label: label,
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected ? p.border : Colors.transparent,
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
