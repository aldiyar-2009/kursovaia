import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/due_format.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/domain/grading_rules.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';
import 'package:studyplan/features/home/domain/home_agenda.dart';

String _localeTag(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

String _hm(BuildContext context, DateTime t) =>
    DateFormat.Hm(_localeTag(context)).format(t);

/// `09:00–10:50`, or only the start when the end is unknown.
String timeRange(BuildContext context, AgendaLesson l) {
  final start = _hm(context, l.start);
  if (!l.end.isAfter(l.start)) return start;
  return '$start–${_hm(context, l.end)}';
}

/// Lesson type and room, e.g. «Лекция, C1.3.240»; null when neither is known.
String? lessonMeta(BuildContext context, AgendaLesson l) {
  final l10n = context.l10n;
  final type = switch (l.lessonType) {
    'lecture' => l10n.home_lessonLecture,
    'practice' => l10n.home_lessonPractice,
    'lab' => l10n.home_lessonLab,
    _ => null,
  };
  final room = l.room?.trim();
  final parts = [?type, if (room != null && room.isNotEmpty) room];
  return parts.isEmpty ? null : parts.join(', ');
}

/// Section heading on Home. Unlike the shared `SectionHeader` it has no
/// horizontal padding of its own: Home's list already sits in the content
/// column, so the heading starts at the same x as the row groups below it.
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const HomeSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.text.labelMedium!
                    .copyWith(color: context.palette.textSecondary),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Compact link on the right of a section header.
class SectionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SectionLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: context.palette.accent,
        textStyle: context.text.labelMedium,
      ),
      child: Text(label),
    );
  }
}

/// A later lesson today: start/end in a fixed time column, then title.
class LessonRow extends StatelessWidget {
  static const double timeColumnWidth = 60;

  final AgendaLesson lesson;

  const LessonRow({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final meta = lessonMeta(context, lesson);
    final hasEnd = lesson.end.isAfter(lesson.start);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: timeColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hm(context, lesson.start),
                    style: context.text.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w500)
                        .tabular,
                  ),
                  if (hasEnd)
                    Text(
                      _hm(context, lesson.end),
                      style: context.text.bodySmall!
                          .copyWith(color: p.textTertiary)
                          .tabular,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                  if (meta != null || lesson.fromLms) ...[
                    const SizedBox(height: 2),
                    _MetaLine(
                      label: lesson.fromLms ? context.l10n.home_sourceLms : null,
                      text: meta,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional source label followed by secondary text, on one line.
class _MetaLine extends StatelessWidget {
  final String? label;
  final String? text;

  const _MetaLine({this.label, this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          StatusLabel(text: label!, tone: StatusTone.neutral),
          if (text != null) const SizedBox(width: 8),
        ],
        if (text != null)
          Flexible(
            child: Text(
              text!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// A task or LMS deadline with its due moment on the right.
class DeadlineRow extends StatelessWidget {
  final AgendaDeadline deadline;
  final DateTime now;
  final VoidCallback? onTap;

  const DeadlineRow({
    super.key,
    required this.deadline,
    required this.now,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final overdue = deadline.due.isBefore(now);
    final label = switch (deadline.source) {
      DeadlineSource.lms => l10n.home_sourceLms,
      DeadlineSource.group => l10n.home_sourceGroup,
      DeadlineSource.own => null,
    };
    final subject = deadline.subject?.trim();
    final hasMeta = label != null || (subject != null && subject.isNotEmpty);

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: hasMeta ? 64 : 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deadline.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                  if (hasMeta) ...[
                    const SizedBox(height: 4),
                    _MetaLine(
                      label: label,
                      text: subject != null && subject.isNotEmpty
                          ? subject
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDue(context, deadline.due, now: now),
              style: context.text.bodySmall!
                  .copyWith(color: overdue ? p.danger : p.textSecondary)
                  .tabular,
            ),
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

/// A course with its total and letter.
class GradeRow extends StatelessWidget {
  final AgendaGrade grade;
  final VoidCallback? onTap;

  const GradeRow({super.key, required this.grade, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final letterColor = switch (grade.status) {
      CourseStatus.failed => p.danger,
      CourseStatus.atRisk => p.warning,
      _ when grade.total >= kIncreasedScholarship => p.success,
      _ => p.textPrimary,
    };
    // Same format as the Grades tab (one decimal, dot, like the LMS).
    final total = formatScore(grade.total);
    return ListRow(
      title: grade.title,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(total),
          const SizedBox(width: 12),
          SizedBox(
            width: 28,
            child: Text(
              grade.letter.letter,
              textAlign: TextAlign.end,
              style: context.text.titleSmall!.copyWith(color: letterColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// First-steps checklist; satisfied steps are not passed in.
class FirstSteps extends StatelessWidget {
  final List<FirstStep> steps;
  final ValueChanged<FirstStep> onStep;

  /// True when nothing else is on the screen above the checklist.
  final bool compactTop;

  /// False where LMS import is unavailable (web): the grades step then
  /// offers manual entry instead of the import.
  final bool lmsImportAvailable;

  const FirstSteps({
    super.key,
    required this.steps,
    required this.onStep,
    this.compactTop = false,
    this.lmsImportAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // No horizontal padding: the list already sits in the content
        // column, so the heading lines up with the row group below.
        Padding(
          padding: EdgeInsets.only(top: compactTop ? 16 : 32, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.home_firstStepsTitle,
                  style: context.text.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.home_firstStepsMessage,
                style: context.text.bodyMedium!
                    .copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        ListGroup(
          dividerIndent: 16 + 22 + 12,
          children: [
            for (final step in steps)
              ListRow(
                leading: const Icon(Icons.radio_button_unchecked),
                title: switch (step) {
                  FirstStep.schedule => l10n.home_stepSchedule,
                  FirstStep.lms => lmsImportAvailable
                      ? l10n.home_stepLms
                      : l10n.home_stepGradesManual,
                  FirstStep.group => l10n.home_stepGroup,
                },
                subtitle: switch (step) {
                  FirstStep.schedule => l10n.home_stepScheduleHint,
                  FirstStep.lms => lmsImportAvailable
                      ? l10n.home_stepLmsHint
                      : l10n.home_stepGradesManualHint,
                  FirstStep.group => l10n.home_stepGroupHint,
                },
                trailing: const ListRowChevron(),
                onTap: () => onStep(step),
              ),
          ],
        ),
      ],
    );
  }
}
