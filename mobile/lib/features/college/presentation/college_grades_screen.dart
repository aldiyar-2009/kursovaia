import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/charts.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/college/data/college_models.dart';
import 'package:studyplan/features/college/data/college_repository.dart';
import 'package:studyplan/features/college/domain/college_analytics.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';

/// Tone of a 100-point college mark or average.
StatusTone collegeTone(double value) {
  if (value >= kCollegeAtRisk) return StatusTone.success;
  if (value >= kCollegeFail) return StatusTone.warning;
  return StatusTone.danger;
}

/// College «Оценки» tab: SmartNation journal summary, analytics and subjects.
class CollegeGradesScreen extends StatefulWidget {
  /// Null for guests: the tab explains that grades need a SmartNation login.
  final CollegeRepository? repository;
  final VoidCallback? onSignIn;

  const CollegeGradesScreen({super.key, this.repository, this.onSignIn});

  @override
  State<CollegeGradesScreen> createState() => _CollegeGradesScreenState();
}

class _CollegeGradesScreenState extends State<CollegeGradesScreen> {
  SnSnapshot? _snapshot;
  bool _fromCache = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final repo = widget.repository;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }
    if (_snapshot == null) {
      final cached = await repo.cachedSnapshot();
      if (mounted && cached != null) setState(() => _snapshot = cached);
    }
    if (mounted) setState(() => _loading = true);
    final result = await repo.loadSnapshot(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _snapshot = result.snapshot ?? _snapshot;
      _fromCache = result.fromCache;
      _loading = false;
    });
  }

  void _openSubject(SnSubject subject) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollegeSubjectScreen(subject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(
        title: Text(l10n.grades_title),
        actions: [
          if (widget.repository != null)
            _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('college_refresh'),
                    tooltip: l10n.college_refresh,
                    icon: const Icon(Icons.sync_outlined),
                    onPressed: () => _load(refresh: true),
                  ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    if (widget.repository == null) {
      return EmptyState(
        title: l10n.college_gradesGuestTitle,
        message: l10n.college_gradesGuestMessage,
        actionLabel: widget.onSignIn == null ? null : l10n.guest_signIn,
        onAction: widget.onSignIn,
      );
    }
    final snap = _snapshot;
    if (snap == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return EmptyState(
        title: l10n.college_gradesEmptyTitle,
        message: l10n.college_gradesEmptyMessage,
        actionLabel: l10n.college_refresh,
        onAction: () => _load(refresh: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: contentPadding(constraints.maxWidth, top: 8, bottom: 32),
          children: _content(context, snap),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, SnSnapshot snap) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final stats = snap.stats;
    final months = monthlyAverages(snap.subjects);
    final bands = markBands(snap.subjects);
    final ranked = subjectsByAverage(snap.subjects);
    final absences = subjectsByAbsences(snap.subjects);
    final trend = lastMonthTrend(snap.subjects);
    final atRisk = snap.subjects
        .where((s) => s.average != null && s.average! < kCollegeAtRisk)
        .toList();
    final profile = [
      if (snap.group != null) snap.group!,
      if (snap.course != null) l10n.college_course(snap.course!),
      if (snap.qualification != null) snap.qualification!,
    ].join(' · ');

    Color tone(double v) => switch (collegeTone(v)) {
      StatusTone.success => p.success,
      StatusTone.warning => p.warning,
      _ => p.danger,
    };

    return [
      if (profile.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(profile, style: context.text.bodySmall),
        ),
      StatStrip(
        items: [
          (
            l10n.college_average,
            stats.gpa == null
                ? l10n.grades_scoreEmpty
                : formatScore(stats.gpa!),
          ),
          (l10n.college_excellent, '${stats.excellentCount}'),
          (l10n.college_retakes, '${stats.retakesCount}'),
          (l10n.college_absences, '${stats.absences}'),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Text(
          [
            if (snap.syncedAt != null)
              l10n.college_updatedAt(formatDateTime(context, snap.syncedAt!)),
            if (_fromCache) l10n.college_offline,
          ].join(' · '),
          style: context.text.bodySmall!.copyWith(color: p.textTertiary),
        ),
      ),
      if (atRisk.isNotEmpty) ...[
        SectionHeader(l10n.college_atRisk),
        ListGroup(
          children: [
            for (final s in atRisk)
              ListRow(
                title: s.name,
                subtitle: l10n.college_atRiskHint,
                trailing: StatusLabel(
                  text: formatScore(s.average!),
                  tone: collegeTone(s.average!),
                ),
                onTap: () => _openSubject(s),
              ),
          ],
        ),
      ],
      if (months.isNotEmpty) ...[
        const SizedBox(height: 16),
        ChartCard(
          title: l10n.college_byMonth,
          subtitle: trend == null
              ? null
              : trend >= 0
              ? l10n.college_trendUp(formatScore(trend))
              : l10n.college_trendDown(formatScore(-trend)),
          child: ColumnChart(
            max: 100,
            bars: [
              for (final (month, avg, _) in months)
                ChartBar(
                  DateFormat('LLL', locale).format(month),
                  avg,
                  valueText: avg.toStringAsFixed(0),
                  color: tone(avg),
                ),
            ],
          ),
        ),
      ],
      if (bands.total > 0) ...[
        const SizedBox(height: 16),
        ChartCard(
          title: l10n.college_bands,
          subtitle: l10n.college_gradesCount(stats.gradesCount),
          child: BarList(
            bars: [
              ChartBar('90–100', bands.excellent.toDouble(), color: p.success),
              ChartBar('70–89', bands.good.toDouble(), color: p.accent),
              ChartBar(
                '50–69',
                bands.satisfactory.toDouble(),
                color: p.warning,
              ),
              ChartBar('< 50', bands.failing.toDouble(), color: p.danger),
            ],
          ),
        ),
      ],
      if (absences.isNotEmpty) ...[
        const SizedBox(height: 16),
        ChartCard(
          title: l10n.college_absencesBySubject,
          child: BarList(
            bars: [
              for (final s in absences)
                ChartBar(s.name, s.absences.toDouble(), color: p.warning),
            ],
          ),
        ),
      ],
      SectionHeader(l10n.college_subjects),
      if (snap.subjects.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.college_noSubjects, style: context.text.bodySmall),
        )
      else
        ListGroup(
          children: [
            for (final s in [
              ...ranked,
              ...snap.subjects.where((s) => s.average == null),
            ])
              ListRow(
                title: s.name,
                subtitle: [
                  if (s.teacher != null && s.teacher!.isNotEmpty) s.teacher!,
                  l10n.college_gradesCount(
                    s.grades.where((g) => g.value != null).length,
                  ),
                ].join(' · '),
                trailing: s.average == null
                    ? Text(l10n.grades_scoreEmpty)
                    : StatusLabel(
                        text: formatScore(s.average!),
                        tone: collegeTone(s.average!),
                      ),
                onTap: () => _openSubject(s),
              ),
          ],
        ),
    ];
  }
}

/// Every mark of one subject with the lesson theme, newest first.
class CollegeSubjectScreen extends StatelessWidget {
  final SnSubject subject;

  const CollegeSubjectScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final grades = [...subject.grades]
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    final recent = recentAverage(subject);
    return Scaffold(
      appBar: ContentAppBar(title: Text(subject.name)),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: contentPadding(constraints.maxWidth, top: 8, bottom: 32),
          children: [
            StatStrip(
              items: [
                (
                  l10n.college_average,
                  subject.average == null
                      ? l10n.grades_scoreEmpty
                      : formatScore(subject.average!),
                ),
                (
                  l10n.college_recent,
                  recent == null ? l10n.grades_scoreEmpty : formatScore(recent),
                ),
                (l10n.college_absences, '${subject.absences}'),
              ],
            ),
            if (subject.teacher != null || subject.kind != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  [
                    subject.teacher,
                    subject.kind,
                  ].whereType<String>().join(' · '),
                  style: context.text.bodySmall!.copyWith(
                    color: p.textTertiary,
                  ),
                ),
              ),
            SectionHeader(l10n.college_journal),
            if (grades.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.college_noGrades,
                  style: context.text.bodySmall,
                ),
              )
            else
              ListGroup(
                children: [
                  for (final g in grades)
                    ListRow(
                      title: g.theme?.isNotEmpty == true
                          ? g.theme!
                          : (g.isExam
                                ? l10n.college_exam
                                : l10n.college_lesson),
                      subtitle: [
                        if (g.day != null)
                          DateFormat('d MMMM', locale).format(g.day!),
                        if (g.isExam) l10n.college_exam,
                      ].join(' · '),
                      trailing: _Mark(grade: g),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  final SnGrade grade;

  const _Mark({required this.grade});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (grade.absent) {
      return StatusLabel(
        text: l10n.college_absentMark,
        tone: StatusTone.warning,
      );
    }
    final value = grade.value;
    if (value == null) {
      return Text(grade.label.isEmpty ? l10n.grades_scoreEmpty : grade.label);
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      child: StatusLabel(
        text: grade.label.isEmpty ? value.toStringAsFixed(0) : grade.label,
        tone: grade.failed ? StatusTone.danger : collegeTone(value),
      ),
    );
  }
}
