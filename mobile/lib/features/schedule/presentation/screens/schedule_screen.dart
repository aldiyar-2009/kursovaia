import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/lesson_dao.dart';
import 'package:studyplan/core/database/subject_dao.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/date_util.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/calendar/presentation/screens/academic_calendar_screen.dart';
import 'package:studyplan/features/schedule/domain/schedule_rules.dart';
import 'package:studyplan/features/schedule/presentation/widgets/lesson_edit_sheet.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/features/schedule/presentation/widgets/week_strip.dart';

enum _Mode { lessons, calendar }

/// Schedule tab: week of manual lessons and LMS class sessions, plus the
/// academic calendar behind a «Пары / Календарь» switch.
class ScheduleScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// Group semester start (`groups.semester_start`); null = 1 September.
  final DateTime? semesterStart;

  /// Overrides "today" (tests); defaults to the current date.
  final DateTime? today;

  const ScheduleScreen({
    super.key,
    required this.db,
    required this.userId,
    this.semesterStart,
    this.today,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final Stream<List<Lesson>> _lessons;
  late final Stream<List<LmsEvent>> _classes;
  late final Stream<List<Subject>> _subjects;
  late DateTime _selected;
  _Mode _mode = _Mode.lessons;

  DateTime get _today => dayOnly(widget.today ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _lessons = LessonDao(widget.db).watchAllLessons(widget.userId);
    _classes = widget.db.lmsDao.watchEvents(widget.userId, type: 'class');
    _subjects = SubjectDao(widget.db).watchAllSubjects(widget.userId);
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day + 7 * weeks,
      );
    });
  }

  void _addLesson() {
    LessonEditSheet.show(
      context,
      db: widget.db,
      userId: widget.userId,
      initialDate: _selected,
    );
  }

  void _editLesson(Lesson lesson) {
    LessonEditSheet.show(
      context,
      db: widget.db,
      userId: widget.userId,
      initialDate: _selected,
      lesson: lesson,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(
        title: Text(l10n.schedule_title),
        actions: [
          if (_mode == _Mode.lessons)
            IconButton(
              tooltip: l10n.schedule_addLesson,
              onPressed: _addLesson,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Left/right edge of the content column; the app bar title, the
          // toggle and the lesson list all start here.
          final inset = contentInset(constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SegmentedToggle<_Mode>(
                      key: const ValueKey('schedule-mode-toggle'),
                      expand: true,
                      segments: [
                        (_Mode.lessons, l10n.schedule_tabLessons),
                        (_Mode.calendar, l10n.schedule_tabCalendar),
                      ],
                      value: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _mode == _Mode.lessons
                    ? _lessonsBody(context, inset)
                    : AcademicCalendarView(today: _today),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _lessonsBody(BuildContext context, double inset) {
    return StreamBuilder<List<Lesson>>(
      stream: _lessons,
      builder: (context, lessonSnap) => StreamBuilder<List<LmsEvent>>(
        stream: _classes,
        builder: (context, classSnap) => StreamBuilder<List<Subject>>(
          stream: _subjects,
          builder: (context, subjectSnap) {
            final lessons = lessonSnap.data;
            final classes = classSnap.data;
            if (lessons == null || classes == null) {
              return const SizedBox.shrink();
            }
            if (lessons.isEmpty && classes.isEmpty) {
              final l10n = context.l10n;
              return EmptyState(
                title: l10n.schedule_emptyTitle,
                message: l10n.schedule_emptyMessage,
                actionLabel: l10n.schedule_addLesson,
                onAction: _addLesson,
              );
            }
            final subjects = {
              for (final s in subjectSnap.data ?? const <Subject>[]) s.id: s,
            };
            return _week(context, lessons, classes, subjects, inset);
          },
        ),
      ),
    );
  }

  Widget _week(
    BuildContext context,
    List<Lesson> lessons,
    List<LmsEvent> classes,
    Map<String, Subject> subjects,
    double inset,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monday = mondayOf(_selected);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final busy = <int>{};
    for (var i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      final has = entriesForDay(
        d,
        lessons: lessons,
        lmsClasses: classes,
        semesterStart: widget.semesterStart,
      ).isNotEmpty;
      if (has) busy.add(d.weekday);
    }
    final entries = entriesForDay(
      _selected,
      lessons: lessons,
      lmsClasses: classes,
      semesterStart: widget.semesterStart,
    );

    final week = DateUtil.academicWeekNumber(
      _selected,
      semesterStart: widget.semesterStart,
    );
    final weekTitle = week < 1
        ? l10n.schedule_beforeSemester
        : l10n.schedule_weekHeader(
            week,
            week.isEven ? l10n.schedule_parityEven : l10n.schedule_parityOdd,
          );
    final dayMonth = DateFormat('d MMMM', locale);
    final range = '${dayMonth.format(monday)} – ${dayMonth.format(sunday)}';
    final isCurrentWeek = dateKey(monday) == dateKey(mondayOf(_today));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // IconButtons carry their own padding on the right.
          padding: EdgeInsets.fromLTRB(inset, 8, inset - 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium!.tabular,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      range,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.tabular,
                    ),
                  ],
                ),
              ),
              if (!isCurrentWeek)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => setState(() => _selected = _today),
                  child: Text(l10n.schedule_today),
                ),
              IconButton(
                tooltip: l10n.schedule_prevWeek,
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: l10n.schedule_nextWeek,
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset - 2, vertical: 4),
          child: WeekStrip(
            monday: monday,
            selected: _selected,
            today: _today,
            busyWeekdays: busy,
            onSelect: (d) => setState(() => _selected = d),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _capitalize(
                    DateFormat('EEEE, d MMMM', locale).format(_selected),
                  ),
                  style: context.text.labelMedium!.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.schedule_emptyDay,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium!.copyWith(
                      color: p.textTertiary,
                    ),
                  ),
                )
              else
                ListGroup(
                  dividerIndent: 80,
                  children: [
                    for (final e in entries)
                      _EntryRow(
                        entry: e,
                        subject: subjects[e.subjectId],
                        onTap: e.lesson == null
                            ? null
                            : () => _editLesson(e.lesson!),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _EntryRow extends StatelessWidget {
  final ScheduleEntry entry;
  final Subject? subject;
  final VoidCallback? onTap;

  const _EntryRow({required this.entry, this.subject, this.onTap});

  String _typeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    return switch (type) {
      'practice' => l10n.schedule_typePractice,
      'lab' => l10n.schedule_typeLab,
      _ => l10n.schedule_typeLecture,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final String title;
    final List<String> details;
    final lesson = entry.lesson;
    final lms = entry.lmsEvent;
    if (lesson != null) {
      title = subject?.title ?? l10n.schedule_lessonUntitled;
      details = [
        _typeLabel(context, lesson.lessonType),
        if (lesson.classroom != null && lesson.classroom!.trim().isNotEmpty)
          lesson.classroom!.trim(),
        if (subject?.teacherName != null &&
            subject!.teacherName!.trim().isNotEmpty)
          subject!.teacherName!.trim(),
      ];
    } else {
      final course = lms!.courseTitle?.trim();
      title = course == null || course.isEmpty ? lms.title : course;
      details = [
        if (lms.location != null && lms.location!.trim().isNotEmpty)
          lms.location!.trim(),
      ];
    }

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.start,
                    style: context.text.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w500)
                        .tabular,
                  ),
                  if (entry.end != null)
                    Text(
                      entry.end!,
                      style: context.text.bodySmall!
                          .copyWith(color: p.textTertiary)
                          .tabular,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (entry.isLms) ...[
              const SizedBox(width: 12),
              StatusLabel(
                text: l10n.schedule_lmsLabel,
                tone: StatusTone.neutral,
              ),
            ],
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
