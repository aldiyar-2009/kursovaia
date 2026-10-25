import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/app_palette.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/calendar/data/models/academic_event.dart';

/// Academic calendar 2026/2027 as a list of rows. Embedded in the Schedule
/// tab under the «Календарь» segment (no own Scaffold).
class AcademicCalendarView extends StatelessWidget {
  /// Day used to mark the current events; defaults to now.
  final DateTime? today;

  const AcademicCalendarView({super.key, this.today});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = today ?? DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: contentPadding(constraints.maxWidth, bottom: 24),
        children: [
          SectionHeader(l10n.schedule_calendarYear),
          ListGroup(
            children: [
              for (final e in kAcademicEvents2026)
                _EventRow(event: e, isCurrent: e.contains(now)),
            ],
          ),
        ],
      ),
    );
  }
}

Color academicCategoryColor(AcademicCategory c, AppPalette p) => switch (c) {
  AcademicCategory.study => p.accent,
  AcademicCategory.control => p.warning,
  AcademicCategory.session => p.danger,
  AcademicCategory.holidays => p.success,
  AcademicCategory.publicHoliday => p.textSecondary,
  AcademicCategory.practice => p.textTertiary,
};

String formatAcademicRange(
  AcademicEvent e,
  String locale,
  String Function(String) from,
) {
  final full = DateFormat('d MMMM y', locale);
  final end = e.end;
  if (end == null) return from(full.format(e.start));
  if (e.start.year == end.year && e.start.month == end.month) {
    return '${e.start.day}–${full.format(end)}';
  }
  if (e.start.year == end.year) {
    return '${DateFormat('d MMMM', locale).format(e.start)} – ${full.format(end)}';
  }
  return '${full.format(e.start)} – ${full.format(end)}';
}

class _EventRow extends StatelessWidget {
  final AcademicEvent event;
  final bool isCurrent;

  const _EventRow({required this.event, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: academicCategoryColor(event.category, p),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title(l10n),
                        style: context.text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrent) ...[
                      StatusLabel(
                        text: l10n.schedule_calendarNow,
                        tone: StatusTone.neutral,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        academicCategoryLabel(event.category, l10n),
                        style: context.text.labelSmall!.copyWith(
                          color: p.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatAcademicRange(
                    event,
                    locale,
                    l10n.schedule_calendarFrom,
                  ),
                  style: context.text.bodySmall!
                      .copyWith(color: p.textSecondary)
                      .tabular,
                ),
                const SizedBox(height: 2),
                Text(
                  event.description(l10n),
                  style: context.text.bodySmall!.copyWith(
                    color: p.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
