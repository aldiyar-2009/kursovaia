import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Height of a filter chip.
const double kFilterChipHeight = 32;

/// Horizontally scrollable row of single-select filter chips.
///
/// Place it full width (outside the content padding): it adds
/// [horizontalPadding] (16 by default) before the first and after the last
/// chip itself, so chips scroll edge to edge. Selected chip is filled with
/// `primary` / `onPrimary`, the others are outlined.
class FilterChipsRow<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double horizontalPadding;

  const FilterChipsRow({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kFilterChipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (v, label) = items[i];
          return AppFilterChip(
            label: label,
            selected: v == value,
            onTap: () {
              if (v != value) onChanged(v);
            },
          );
        },
      ),
    );
  }
}

/// A single 32 px filter chip; used by [FilterChipsRow].
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.primary : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? p.primary : p.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: kFilterChipHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              maxLines: 1,
              style: context.text.labelMedium!.copyWith(
                color: selected ? p.onPrimary : p.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
