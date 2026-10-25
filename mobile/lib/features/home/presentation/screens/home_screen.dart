import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/lesson_dao.dart';
import 'package:studyplan/core/database/subject_dao.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/date_util.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/home/domain/home_agenda.dart';
import 'package:studyplan/features/home/presentation/widgets/home_rows.dart';
import 'package:studyplan/features/home/presentation/widgets/now_block.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

/// «Главная»: what is happening today, what is due this week and which
/// grades changed last — read reactively from drift, nothing invented.
class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// Switches the shell to another tab («Все задания», «Все оценки», steps).
  final void Function(AppTab) onOpenTab;

  /// Opens the group screen from the first-steps checklist.
  final VoidCallback? onOpenGroup;

  /// Current group; group tasks are shown and the group step is hidden
  /// when set.
  final String? groupId;

  /// Source of "now"; injectable for tests.
  final DateTime Function() clock;

  /// Whether the grades step offers the LMS import; on web it offers manual
  /// entry instead. Defaults to `!kIsWeb`; injectable for tests.
  final bool? lmsImportAvailable;

  const HomeScreen({
    super.key,
    required this.db,
    required this.userId,
    required this.onOpenTab,
    this.onOpenGroup,
    this.groupId,
    this.clock = DateTime.now,
    this.lmsImportAvailable,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _ticker;

  List<Subject>? _subjects;
  List<Lesson>? _lessons;
  List<Task>? _tasks;
  List<LmsEvent>? _events;
  List<LmsCourse>? _courses;

  bool get _ready =>
      _subjects != null &&
      _lessons != null &&
      _tasks != null &&
      _events != null &&
      _courses != null;

  @override
  void initState() {
    super.initState();
    _subscribe();
    // Keeps «Сейчас / Далее» and the countdown current.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.groupId != widget.groupId ||
        oldWidget.db != widget.db) {
      _cancel();
      _subjects = null;
      _lessons = null;
      _tasks = null;
      _events = null;
      _courses = null;
      _subscribe();
    }
  }

  void _subscribe() {
    final db = widget.db;
    final userId = widget.userId;
    final now = widget.clock();
    final dayStart = DateTime(now.year, now.month, now.day);

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((value) {
        if (mounted) setState(() => assign(value));
      }));
    }

    listen(SubjectDao(db).watchAllSubjects(userId), (v) => _subjects = v);
    listen(LessonDao(db).watchAllLessons(userId), (v) => _lessons = v);
    listen(
      TaskDao(db).watchTasks(userId: userId, groupId: widget.groupId),
      (v) => _tasks = v,
    );
    // Rows before today are filtered out in memory, so a lower bound fixed at
    // subscription time stays correct after midnight.
    listen(
      db.lmsDao.watchEvents(userId, fromMs: dayStart.millisecondsSinceEpoch),
      (v) => _events = v,
    );
    listen(db.lmsDao.watchCourses(userId), (v) => _courses = v);
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    return Scaffold(
      appBar: ContentAppBar(title: _DateTitle(now: now)),
      body: _ready
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  _content(context, now, constraints.maxWidth),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _content(BuildContext context, DateTime now, double width) {
    final l10n = context.l10n;

    final today = lessonsForDay(
      now: now,
      lessons: _lessons!,
      subjects: _subjects!,
      lmsEvents: _events!,
    );
    final upcoming = upcomingToday(now, today);
    final deadlines = upcomingDeadlines(
      now: now,
      tasks: _tasks!,
      lmsEvents: _events!,
    );
    final grades = recentGrades(_courses!);
    final steps = remainingFirstSteps(
      hasLessons: _lessons!.isNotEmpty,
      hasCourses: _courses!.isNotEmpty,
      hasGroup: widget.groupId != null && widget.groupId!.isNotEmpty,
    ).where((s) => s != FirstStep.group || widget.onOpenGroup != null).toList();

    final hasSections =
        upcoming.isNotEmpty || deadlines.isNotEmpty || grades.isNotEmpty;

    if (!hasSections && steps.isEmpty) {
      return EmptyState(
        title: l10n.home_quietTitle,
        message: l10n.home_quietMessage,
        actionLabel: l10n.home_openSchedule,
        onAction: () => widget.onOpenTab(AppTab.schedule),
      );
    }

    final children = <Widget>[
      if (upcoming.isNotEmpty) ...[
        const SizedBox(height: 8),
        NowBlock(lesson: upcoming.first, now: now),
        if (upcoming.length > 1) ...[
          HomeSectionHeader(l10n.home_laterToday),
          ListGroup(
            dividerIndent: 16 + LessonRow.timeColumnWidth,
            children: [
              for (final lesson in upcoming.skip(1)) LessonRow(lesson: lesson),
            ],
          ),
        ],
      ],
      if (deadlines.isNotEmpty) ...[
        HomeSectionHeader(
          l10n.home_deadlines,
          trailing: SectionLink(
            label: l10n.home_allTasks,
            onTap: () => widget.onOpenTab(AppTab.tasks),
          ),
        ),
        ListGroup(children: [
          for (final d in deadlines)
            DeadlineRow(
              deadline: d,
              now: now,
              onTap: () => widget.onOpenTab(AppTab.tasks),
            ),
        ]),
      ],
      if (grades.isNotEmpty) ...[
        HomeSectionHeader(
          l10n.home_grades,
          trailing: SectionLink(
            label: l10n.home_allGrades,
            onTap: () => widget.onOpenTab(AppTab.grades),
          ),
        ),
        ListGroup(children: [
          for (final g in grades)
            GradeRow(
              grade: g,
              onTap: () => widget.onOpenTab(AppTab.grades),
            ),
        ]),
      ],
      if (steps.isNotEmpty)
        FirstSteps(
          steps: steps,
          compactTop: !hasSections,
          lmsImportAvailable: widget.lmsImportAvailable ?? !kIsWeb,
          onStep: (step) {
            switch (step) {
              case FirstStep.schedule:
                widget.onOpenTab(AppTab.schedule);
              case FirstStep.lms:
                widget.onOpenTab(AppTab.grades);
              case FirstStep.group:
                widget.onOpenGroup?.call();
            }
          },
        ),
      const SizedBox(height: 32),
    ];

    return ListView(padding: contentPadding(width), children: children);
  }
}

/// Today's weekday and date in the current locale, with week parity below.
class _DateTitle extends StatelessWidget {
  final DateTime now;

  const _DateTitle({required this.now});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final raw = DateFormat('EEEE, d MMMM', locale).format(now);
    final title = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
    final even = DateUtil.isEvenWeek(now);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          even ? context.l10n.home_weekEven : context.l10n.home_weekOdd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium,
        ),
      ],
    );
  }
}
