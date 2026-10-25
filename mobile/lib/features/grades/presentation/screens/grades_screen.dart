import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';
import 'package:studyplan/features/grades/presentation/screens/course_detail_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/course_form_screen.dart';
import 'package:studyplan/features/grades/presentation/widgets/course_row.dart';
import 'package:studyplan/features/grades/presentation/widgets/grades_summary.dart';

/// Grades tab: semester summary, current courses, collapsed past semesters.
class GradesScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// Opens the LMS import flow; null while import is unavailable.
  final VoidCallback? onImportLms;

  const GradesScreen({
    super.key,
    required this.db,
    required this.userId,
    this.onImportLms,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  late Stream<List<LmsCourse>> _courses;
  bool _pastExpanded = false;

  @override
  void initState() {
    super.initState();
    _courses = widget.db.lmsDao.watchCourses(widget.userId);
  }

  @override
  void didUpdateWidget(GradesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.db != widget.db || oldWidget.userId != widget.userId) {
      _courses = widget.db.lmsDao.watchCourses(widget.userId);
    }
  }

  bool get _canImport => !kIsWeb && widget.onImportLms != null;

  void _openCourse(LmsCourse course) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CourseDetailScreen(
        db: widget.db,
        userId: widget.userId,
        courseId: course.id,
      ),
    ));
  }

  void _addManual() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CourseFormScreen(db: widget.db, userId: widget.userId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<List<LmsCourse>>(
      stream: _courses,
      builder: (context, snapshot) {
        final courses = snapshot.data;
        final hasCourses = courses != null && courses.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.grades_title),
            actions: [
              if (hasCourses && _canImport)
                IconButton(
                  tooltip: l10n.grades_refreshLms,
                  icon: const Icon(Icons.sync_outlined),
                  onPressed: widget.onImportLms,
                ),
              if (hasCourses)
                IconButton(
                  tooltip: l10n.grades_addManual,
                  icon: const Icon(Icons.add),
                  onPressed: _addManual,
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: courses == null
              ? const SizedBox.shrink()
              : courses.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, courses),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final l10n = context.l10n;
    if (_canImport) {
      return EmptyState(
        title: l10n.grades_emptyTitle,
        message: l10n.grades_emptyMessage,
        actionLabel: l10n.grades_importLms,
        onAction: widget.onImportLms,
        secondaryLabel: l10n.grades_addManual,
        onSecondary: _addManual,
      );
    }
    return EmptyState(
      title: l10n.grades_emptyTitle,
      message: kIsWeb
          ? l10n.grades_emptyMessageWeb
          : l10n.grades_emptyMessageNoImport,
      actionLabel: l10n.grades_addManual,
      onAction: _addManual,
    );
  }

  Widget _buildList(BuildContext context, List<LmsCourse> courses) {
    final l10n = context.l10n;
    final palette = context.palette;
    final current = courses.where(isCurrentCourse).toList();
    final past = courses.where((c) => !isCurrentCourse(c)).toList();
    final currentScores = current.map(scoresOf).toList();
    final overallGpa = gpa(courses.map(scoresOf));

    final imports = courses.map((c) => c.importedAt).whereType<BigInt>();
    final lastImport = imports.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            imports.reduce((a, b) => a > b ? a : b).toInt(),
          );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kGradesMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GradesSummary(
              average: weightedAverage(currentScores),
              gpa: gpa(currentScores),
              scholarship: scholarshipFor(currentScores),
              lastImport: lastImport,
            ),
            _header(l10n.grades_currentSemester),
            if (current.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  l10n.grades_currentEmpty,
                  style: context.text.bodySmall,
                ),
              )
            else
              _CourseGroup(courses: current, onTap: _openCourse),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PastToggle(
                expanded: _pastExpanded,
                count: past.length,
                overallGpa: overallGpa,
                onTap: () => setState(() => _pastExpanded = !_pastExpanded),
              ),
              if (_pastExpanded) ...[
                const SizedBox(height: 8),
                _CourseGroup(courses: past, onTap: _openCourse),
              ],
            ],
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: palette.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListRow(
                title: l10n.grades_addManual,
                leading: const Icon(Icons.add),
                onTap: _addManual,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section titles align with the text inside the row groups below.
  Widget _header(String title) => SectionHeader(title);
}

class _CourseGroup extends StatelessWidget {
  final List<LmsCourse> courses;
  final ValueChanged<LmsCourse> onTap;

  const _CourseGroup({required this.courses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListGroup(
      children: [
        for (final c in courses) CourseRow(course: c, onTap: () => onTap(c)),
      ],
    );
  }
}

/// Collapsed «Прошлые семестры» row with the overall GPA on the right.
class _PastToggle extends StatelessWidget {
  final bool expanded;
  final int count;
  final double? overallGpa;
  final VoidCallback onTap;

  const _PastToggle({
    required this.expanded,
    required this.count,
    required this.overallGpa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListRow(
        title: l10n.grades_pastSemesters,
        subtitle: overallGpa == null
            ? null
            : l10n.grades_overallGpa(formatGpa(overallGpa!)),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count'),
            const SizedBox(width: 4),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}
