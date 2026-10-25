import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/schedule/domain/schedule_rules.dart';

/// Monday–Sunday strip. The selected day is a filled tile, today is marked by
/// an accent-coloured number, days with classes get a small dot.
class WeekStrip extends StatelessWidget {
  final DateTime monday;
  final DateTime selected;
  final DateTime today;

  /// Weekdays (1..7) that have at least one entry.
  final Set<int> busyWeekdays;
  final ValueChanged<DateTime> onSelect;

  const WeekStrip({
    super.key,
    required this.monday,
    required this.selected,
    required this.today,
    required this.busyWeekdays,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekday = DateFormat.E(locale);
    final selectedKey = dateKey(selected);
    final todayKey = dateKey(today);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: _DayCell(
              date: d,
              label: _capitalize(weekday.format(d)),
              selected: dateKey(d) == selectedKey,
              isToday: dateKey(d) == todayKey,
              busy: busyWeekdays.contains(d.weekday),
              onTap: onSelect,
            ),
          ),
      ],
    );
  }
}

String _capitalize(String s) {
  final t = s.replaceAll('.', '');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final String label;
  final bool selected;
  final bool isToday;
  final bool busy;
  final ValueChanged<DateTime> onTap;

  const _DayCell({
    required this.date,
    required this.label,
    required this.selected,
    required this.isToday,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberColor = selected
        ? p.onPrimary
        : isToday
            ? p.accent
            : p.textPrimary;
    final labelColor = selected ? p.onPrimary : p.textTertiary;
    final dotColor = selected ? p.onPrimary : p.textTertiary;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? p.primary : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onTap(date),
            child: SizedBox(
              height: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: context.text.labelSmall!.copyWith(color: labelColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: context.text.titleSmall!
                        .copyWith(
                          color: numberColor,
                          fontWeight: selected || isToday
                              ? FontWeight.w600
                              : FontWeight.w500,
                        )
                        .tabular,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: busy ? dotColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
