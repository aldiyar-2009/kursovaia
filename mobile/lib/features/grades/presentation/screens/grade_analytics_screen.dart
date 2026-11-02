import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/charts.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_analytics.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/domain/grading_rules.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

enum _Scope { current, all }

/// «Аналитика»: where the points come from and what is needed next —
/// component averages, letters, ranking, credits and the final-exam plan.
class GradeAnalyticsScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  const GradeAnalyticsScreen({
    super.key,
    required this.db,
    required this.userId,
  });

  @override
  State<GradeAnalyticsScreen> createState() => _GradeAnalyticsScreenState();
}

class _GradeAnalyticsScreenState extends State<GradeAnalyticsScreen> {
  late final Stream<List<LmsCourse>> _courses = widget.db.lmsDao.watchCourses(
    widget.userId,
  );
  _Scope _scope = _Scope.current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(title: Text(l10n.analytics_title)),
      body: StreamBuilder<List<LmsCourse>>(
        stream: _courses,
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const SizedBox.shrink();
          final rows =
              (_scope == _Scope.current ? all.where(isCurrentCourse) : all)
                  .map(
                    (c) => AnalyticsCourse(
                      id: c.id,
                      title: c.title,
                      scores: scoresOf(c),
                    ),
                  )
                  .toList();
          return LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: contentPadding(constraints.maxWidth, top: 0, bottom: 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SegmentedToggle<_Scope>(
                      expand: true,
                      segments: [
                        (_Scope.current, l10n.analytics_scopeCurrent),
                        (_Scope.all, l10n.analytics_scopeAll),
                      ],
                      value: _scope,
                      onChanged: (s) => setState(() => _scope = s),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  SizedBox(
                    height: 320,
                    child: EmptyState(
                      title: l10n.analytics_emptyTitle,
                      message: l10n.analytics_emptyMessage,
                    ),
                  )
                else
                  ..._content(context, rows),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, List<AnalyticsCourse> rows) {
    final l10n = context.l10n;
    final p = context.palette;
    final scores = rows.map((r) => r.scores).toList();
    final avg = weightedAverage(scores);
    final semesterGpa = gpa(scores);
    final credits = creditSummary(rows);
    final components = componentAverages(rows);
    final ranked = rankedByTotal(rows);
    final attention = coursesNeedingAttention(rows);
    final plans = finalPlans(rows);
    final letters = letterDistribution(rows).where((e) => e.$2 > 0).toList();
    String fmt(double? v) =>
        v == null ? l10n.grades_scoreEmpty : formatScore(v);

    Color toneColor(double total) {
      if (total < kPassThreshold) return p.danger;
      if (total < kRegularScholarship) return p.warning;
      return p.success;
    }

    final trend = components.trend;
    return [
      StatStrip(
        items: [
          (l10n.grades_average, fmt(avg)),
          (
            l10n.grades_gpaSemester,
            semesterGpa == null
                ? l10n.grades_scoreEmpty
                : formatGpa(semesterGpa),
          ),
          (l10n.analytics_credits, '${credits.passed}/${credits.total}'),
        ],
      ),
      const SizedBox(height: 16),
      ChartCard(
        title: l10n.analytics_components,
        subtitle: trend == null
            ? null
            : trend >= 0
            ? l10n.analytics_trendUp(formatScore(trend))
            : l10n.analytics_trendDown(formatScore(-trend)),
        child: BarList(
          max: kMaxScore,
          bars: [
            ChartBar(
              l10n.analytics_midterm,
              components.midterm ?? 0,
              valueText: fmt(components.midterm),
            ),
            ChartBar(
              l10n.analytics_endterm,
              components.endterm ?? 0,
              valueText: fmt(components.endterm),
            ),
            ChartBar(
              l10n.analytics_final,
              components.finalExam ?? 0,
              valueText: fmt(components.finalExam),
            ),
          ],
        ),
      ),
      if (ranked.isNotEmpty) ...[
        const SizedBox(height: 16),
        ChartCard(
          title: l10n.analytics_byCourse,
          child: BarList(
            max: kMaxScore,
            bars: [
              for (final c in ranked)
                ChartBar(
                  c.title,
                  c.total!,
                  valueText: formatScore(c.total!),
                  color: toneColor(c.total!),
                ),
            ],
          ),
        ),
      ],
      if (letters.isNotEmpty) ...[
        const SizedBox(height: 16),
        ChartCard(
          title: l10n.analytics_letters,
          child: ColumnChart(
            max: letters.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m).toDouble(),
            height: 80,
            bars: [
              for (final (letter, count) in letters)
                ChartBar(
                  letter,
                  count.toDouble(),
                  color: letter == kFailLetter ? p.danger : null,
                ),
            ],
          ),
        ),
      ],
      if (attention.isNotEmpty) ...[
        SectionHeader(l10n.analytics_attention),
        ListGroup(
          children: [
            for (final c in attention)
              ListRow(
                title: c.title,
                subtitle: l10n.analytics_attentionHint(
                  fmt(admissionRating(c.scores)),
                  fmt(c.total),
                ),
                trailing: StatusLabel(
                  text: c.status == CourseStatus.failed
                      ? l10n.grades_statusFailed
                      : l10n.grades_statusAtRisk,
                  tone: c.status == CourseStatus.failed
                      ? StatusTone.danger
                      : StatusTone.warning,
                ),
              ),
          ],
        ),
      ],
      if (plans.isNotEmpty) ...[
        SectionHeader(l10n.analytics_finalPlan),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.analytics_finalPlanHint,
            style: context.text.bodySmall,
          ),
        ),
        ListGroup(
          children: [
            for (final plan in plans)
              ListRow(
                title: plan.course.title,
                subtitle: [
                  for (final (target, needed) in plan.targets)
                    '${target.toStringAsFixed(0)}: ${_needed(l10n, needed)}',
                ].join('   '),
              ),
          ],
        ),
      ],
    ];
  }

  String _needed(AppLocalizations l10n, double needed) {
    if (needed <= 0) return l10n.analytics_reached;
    if (needed > kMaxScore) return l10n.analytics_unreachable;
    return needed.ceil().toString();
  }
}
