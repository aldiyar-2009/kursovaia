import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';

/// One course in the grades list: title with status and credits on the
/// left, total and letter right-aligned in tabular figures.
class CourseRow extends StatelessWidget {
  final LmsCourse course;
  final VoidCallback onTap;

  const CourseRow({super.key, required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final scores = scoresOf(course);
    final total = courseTotal(scores);
    final admission = admissionRating(scores);
    final status = courseStatusLabel(l10n, statusFor(scores));

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      // Wraps instead of truncating on narrow screens or with
                      // longer translations.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (status != null)
                            StatusLabel(text: status.$1, tone: status.$2),
                          Text(
                            l10n.grades_credits(course.credits),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall!
                                .copyWith(color: palette.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (total == null && admission != null)
                  // No total yet, but the admission rating is known.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatScore(admission),
                        style: context.text.titleSmall!
                            .copyWith(color: palette.textSecondary)
                            .tabular,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.grades_admissionShort,
                        style: context.text.bodySmall!
                            .copyWith(color: palette.textTertiary),
                      ),
                    ],
                  )
                else if (total == null)
                  Text(
                    l10n.grades_noGrade,
                    style: context.text.bodySmall!
                        .copyWith(color: palette.textTertiary),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatScore(total),
                        style: context.text.titleSmall!.tabular,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        letterFor(total).letter,
                        style: context.text.bodySmall!.tabular,
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
