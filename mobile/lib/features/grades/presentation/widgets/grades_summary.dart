import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';

/// Three figures of the current semester in one bordered strip:
/// weighted average, GPA and scholarship status, plus the last import time.
class GradesSummary extends StatelessWidget {
  final double? average;
  final double? gpa;
  final ScholarshipStatus scholarship;
  final DateTime? lastImport;

  const GradesSummary({
    super.key,
    required this.average,
    required this.gpa,
    required this.scholarship,
    required this.lastImport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final valueStyle = context.text.titleLarge!.tabular;
    final (scholarshipText, scholarshipTone) = scholarshipLabel(
      l10n,
      scholarship,
    );
    // Why a figure is «—»: averages count only courses with a total.
    final noTotals = l10n.grades_summaryNoTotals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    label: l10n.grades_average,
                    caption: average == null ? noTotals : null,
                    child: Text(
                      average == null
                          ? l10n.grades_scoreEmpty
                          : formatScore(average!),
                      style: valueStyle,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Stat(
                    label: l10n.grades_gpaSemester,
                    caption: gpa == null ? noTotals : null,
                    child: Text(
                      gpa == null ? l10n.grades_scoreEmpty : formatGpa(gpa!),
                      style: valueStyle,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Stat(
                    label: l10n.grades_scholarship,
                    child: Padding(
                      // Optically align the label with the numbers' baseline.
                      padding: const EdgeInsets.only(top: 4),
                      child: scholarship == ScholarshipStatus.unknown
                          // Nothing to judge yet: plain text, not a badge.
                          ? Text(
                              scholarshipText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium!.copyWith(
                                color: palette.textSecondary,
                              ),
                            )
                          : StatusLabel(
                              text: scholarshipText,
                              tone: scholarshipTone,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (lastImport != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              l10n.grades_lastImport(formatDateTime(context, lastImport!)),
              style: context.text.bodySmall!.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final Widget child;

  /// Short explanation under an empty value.
  final String? caption;

  const _Stat({required this.label, required this.child, this.caption});

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall,
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: child),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall!.copyWith(
                color: context.palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
