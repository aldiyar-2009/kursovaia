import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/domain/grading_rules.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';
import 'package:studyplan/features/grades/presentation/screens/course_form_screen.dart';
import 'package:studyplan/features/grades/presentation/widgets/what_if_section.dart';

/// One course: components, what is needed on the final, a what-if
/// simulation, credits, and delete for manual courses.
class CourseDetailScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String courseId;

  const CourseDetailScreen({
    super.key,
    required this.db,
    required this.userId,
    required this.courseId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final Stream<List<LmsCourse>> _courses =
      widget.db.lmsDao.watchCourses(widget.userId);
  bool _seen = false;
  bool _closing = false;

  void _closeWhenGone() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _changeCredits(LmsCourse c, int delta) async {
    final next = (c.credits + delta).clamp(kMinCredits, kMaxCredits);
    if (next != c.credits) await widget.db.lmsDao.updateCredits(c.id, next);
  }

  void _edit(LmsCourse c) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          CourseFormScreen(db: widget.db, userId: widget.userId, course: c),
    ));
  }

  Future<void> _delete(LmsCourse c) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.grades_deleteConfirmTitle),
        content: Text(l10n.grades_deleteConfirmMessage(c.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.palette.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.db.lmsDao.softDeleteCourse(c.id);
    // The stream drops the course and the screen closes itself.
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LmsCourse>>(
      stream: _courses,
      builder: (context, snapshot) {
        final all = snapshot.data;
        final course = all?.where((c) => c.id == widget.courseId).firstOrNull;
        if (course != null) _seen = true;
        if (all != null && course == null && _seen) _closeWhenGone();
        return Scaffold(
          appBar: AppBar(),
          body: course == null
              ? const SizedBox.shrink()
              : _buildBody(context, course, all!),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, LmsCourse c, List<LmsCourse> all) {
    final l10n = context.l10n;
    final palette = context.palette;
    final scores = scoresOf(c);
    final admission = admissionRating(scores);
    final total = courseTotal(scores);
    final manual = isManualCourse(c);
    final finalMissing = c.finalExam == null;
    final showNeeded = finalMissing && admission != null;
    final showWhatIf =
        finalMissing && c.registerMidterm != null && c.registerEndterm != null;
    final current = isCurrentCourse(c);
    final semester = all.where((x) => isCurrentCourse(x) == current).toList();

    String score(double? v) =>
        v == null ? l10n.grades_scoreEmpty : formatScore(v);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kGradesMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _Header(course: c, total: total, status: statusFor(scores)),
            SectionHeader(
              l10n.grades_components,
              trailing: manual
                  ? TextButton(
                      onPressed: () => _edit(c),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.grades_edit),
                    )
                  : null,
            ),
            ListGroup(
              children: [
                ListRow(
                  title: l10n.grades_midterm,
                  trailing: Text(score(c.registerMidterm)),
                ),
                ListRow(
                  title: l10n.grades_endterm,
                  trailing: Text(score(c.registerEndterm)),
                ),
                ListRow(
                  title: l10n.grades_admission,
                  trailing: Text(score(admission)),
                ),
                ListRow(
                  title: l10n.grades_finalExam,
                  trailing: Text(score(c.finalExam)),
                ),
                ListRow(
                  title: l10n.grades_total,
                  trailing: Text(
                    total == null ? l10n.grades_noGrade : formatScore(total),
                    style: TextStyle(
                      color: total == null
                          ? palette.textTertiary
                          : palette.textPrimary,
                      fontWeight:
                          total == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (showNeeded) ...[
              SectionHeader(l10n.grades_finalSection),
              _NeededFinal(scores: scores, admission: admission),
            ],
            if (showWhatIf) ...[
              SectionHeader(l10n.grades_whatIf),
              WhatIfSection(
                key: ValueKey('whatif-${c.id}'),
                course: c,
                semester: current ? semester : null,
              ),
            ],
            SectionHeader(l10n.grades_course),
            ListGroup(
              children: [
                ListRow(
                  title: l10n.grades_creditsLabel,
                  trailing: _CreditsStepper(
                    credits: c.credits,
                    onChange: (d) => _changeCredits(c, d),
                  ),
                ),
                if (c.teacherName != null && c.teacherName!.isNotEmpty)
                  ListRow(
                    title: l10n.grades_teacher,
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        c.teacherName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ListRow(
                  title: l10n.grades_source,
                  trailing: Text(
                    manual ? l10n.grades_sourceManual : l10n.grades_sourceLms,
                  ),
                ),
                if (c.importedAt != null)
                  ListRow(
                    title: l10n.grades_imported,
                    trailing: Text(formatDateTime(
                      context,
                      DateTime.fromMillisecondsSinceEpoch(c.importedAt!.toInt()),
                    )),
                  ),
              ],
            ),
            if (manual) ...[
              const SizedBox(height: 24),
              ListGroup(
                children: [
                  ListRow(
                    title: l10n.grades_deleteCourse,
                    titleColor: palette.danger,
                    onTap: () => _delete(c),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LmsCourse course;
  final double? total;
  final CourseStatus status;

  const _Header({
    required this.course,
    required this.total,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final label = courseStatusLabel(l10n, status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(course.title, style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.grades_credits(course.credits),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (total == null)
                Text(
                  l10n.grades_noGrade,
                  style: context.text.titleMedium!
                      .copyWith(color: palette.textTertiary),
                )
              else
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: formatScore(total!),
                      style: context.text.headlineLarge!.tabular,
                    ),
                    TextSpan(
                      text: '  ${letterFor(total!).letter}',
                      style: context.text.titleMedium!
                          .copyWith(color: palette.textSecondary),
                    ),
                  ]),
                ),
              if (label != null) StatusLabel(text: label.$1, tone: label.$2),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minimum final exam scores for a pass and for the top band.
class _NeededFinal extends StatelessWidget {
  final CourseScores scores;
  final double? admission;

  const _NeededFinal({required this.scores, required this.admission});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    if (admission! < kPassThreshold) {
      return ListGroup(
        children: [
          ListRow(title: l10n.grades_noAdmission, titleColor: palette.warning),
        ],
      );
    }

    Widget need(double target) {
      // The exam itself must also be passed, so never ask for less.
      final needed = math.max(requiredFinal(scores, target)!, kPassThreshold);
      if (needed > kMaxScore) {
        return Text(
          l10n.grades_unreachable,
          style: TextStyle(color: palette.danger),
        );
      }
      return Text(
        l10n.grades_needScore(formatScore(needed)),
        style: TextStyle(color: palette.textPrimary),
      );
    }

    return ListGroup(
      children: [
        ListRow(title: l10n.grades_toPass, trailing: need(kPassThreshold)),
        ListRow(
          title: l10n.grades_toGetAtLeast(
            kIncreasedScholarship.toStringAsFixed(0),
          ),
          trailing: need(kIncreasedScholarship),
        ),
      ],
    );
  }
}

class _CreditsStepper extends StatelessWidget {
  final int credits;
  final ValueChanged<int> onChange;

  const _CreditsStepper({required this.credits, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      fixedSize: const Size(36, 36),
      padding: EdgeInsets.zero,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.grades_creditsDecrease,
          style: buttonStyle,
          iconSize: 18,
          onPressed: credits > kMinCredits ? () => onChange(-1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$credits',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium!
                .copyWith(color: palette.textPrimary)
                .tabular,
          ),
        ),
        IconButton(
          tooltip: l10n.grades_creditsIncrease,
          style: buttonStyle,
          iconSize: 18,
          onPressed: credits < kMaxCredits ? () => onChange(1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
