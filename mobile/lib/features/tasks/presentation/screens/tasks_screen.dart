import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/filter_chips.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/tasks/domain/task_group_info.dart';
import 'package:studyplan/features/tasks/domain/task_list_item.dart';
import 'package:studyplan/features/tasks/presentation/widgets/task_detail_bottom_sheet.dart';
import 'package:studyplan/features/tasks/presentation/widgets/task_row.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tasks tab: own tasks, group tasks and LMS deadlines in one list,
/// grouped by due date, with filter chips.
class TasksScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// The user's group (`{id, title, members?}`), or null when not in a group.
  /// SharedPreferences `group_data` is re-read on top of it, so joining a
  /// group elsewhere in the app is picked up without restarting.
  final Map<String, dynamic>? group;

  /// Opens the place where a group can be created or joined.
  final VoidCallback? onOpenGroup;

  /// Source of "now" for grouping and due labels; injectable for tests.
  final DateTime Function() clock;

  const TasksScreen({
    super.key,
    required this.db,
    required this.userId,
    this.group,
    this.onOpenGroup,
    this.clock = DateTime.now,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TaskDao _taskDao = TaskDao(widget.db);
  TaskFilter _filter = TaskFilter.all;
  TaskGroupInfo? _group;

  @override
  void initState() {
    super.initState();
    _group = TaskGroupInfo.fromJson(widget.group);
    _reloadGroup();
  }

  @override
  void didUpdateWidget(TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group != widget.group) {
      _group = TaskGroupInfo.fromJson(widget.group);
      _reloadGroup();
    }
  }

  /// Picks up `group_data` saved by login / the group screen.
  Future<void> _reloadGroup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('group_data');
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final info = TaskGroupInfo.fromJson(decoded);
      if (info != null && mounted) setState(() => _group = info);
    } catch (_) {
      // Corrupt or missing prefs: keep what the shell passed.
    }
  }

  void _setFilter(TaskFilter f) {
    if (f == TaskFilter.group) _reloadGroup();
    setState(() => _filter = f);
  }

  // Streams are cached so rebuilds do not resubscribe (and flash empty).
  Stream<List<Task>>? _tasksStream;
  String? _tasksStreamGroupId;
  late final Stream<List<LmsEvent>> _lmsDeadlines =
      widget.db.lmsDao.watchEvents(widget.userId, type: 'deadline');
  late final Stream<List<Subtask>> _subtasks =
      (widget.db.select(widget.db.subtasks)..where((t) => t.isDeleted.equals(false)))
          .watch();

  Stream<List<Task>> get _tasks {
    final groupId = _group?.id;
    if (_tasksStream == null || _tasksStreamGroupId != groupId) {
      _tasksStreamGroupId = groupId;
      _tasksStream = _taskDao.watchTasks(userId: widget.userId, groupId: groupId);
    }
    return _tasksStream!;
  }

  Future<void> _openEditor({String? taskId}) async {
    await _reloadGroup();
    if (!mounted) return;
    await TaskDetailBottomSheet.show(
      context,
      db: widget.db,
      userId: widget.userId,
      existingTaskId: taskId,
      groupId: _group?.id,
      groupTitle: _group?.title,
      memberNames: _group?.memberNames ?? const {},
    );
  }

  Future<void> _toggle(TaskListItem item) async {
    final wasDone = item.isDone;
    await _setDone(item, !wasDone);
    if (!mounted || wasDone) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(context.l10n.tasks_doneSnack),
      action: SnackBarAction(
        label: context.l10n.tasks_undo,
        onPressed: () => _setDone(item, false),
      ),
    ));
  }

  Future<void> _setDone(TaskListItem item, bool done) {
    if (item.isLms) {
      return widget.db.lmsDao.setEventDone(item.id, done);
    }
    // toggleTaskStatus flips relative to the passed status.
    final current = done ? 'in_progress' : 'completed';
    return _taskDao.toggleTaskStatus(
      item.id,
      current,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _openLms(LmsEvent event) async {
    final url = event.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.tasks_linkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(
        title: Text(l10n.tasks_title),
        actions: [
          IconButton(
            tooltip: l10n.tasks_newTask,
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilterChipsRow<TaskFilter>(
                  key: const ValueKey('tasks-filters'),
                  // First chip starts at the content column edge.
                  horizontalPadding: contentInset(width),
                  items: [
                    (TaskFilter.all, l10n.tasks_filterAll),
                    (TaskFilter.mine, l10n.tasks_filterMine),
                    (TaskFilter.group, l10n.tasks_filterGroup),
                    (TaskFilter.lms, l10n.tasks_filterLms),
                    (TaskFilter.done, l10n.tasks_filterDone),
                  ],
                  value: _filter,
                  onChanged: _setFilter,
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(context, width)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, double width) {
    final l10n = context.l10n;
    if (_filter == TaskFilter.group && _group == null) {
      return EmptyState(
        title: l10n.tasks_noGroupTitle,
        message: l10n.tasks_noGroupMessage,
        actionLabel: widget.onOpenGroup != null ? l10n.tasks_noGroupAction : null,
        onAction: widget.onOpenGroup,
      );
    }
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, taskSnap) {
        return StreamBuilder<List<LmsEvent>>(
          stream: _lmsDeadlines,
          builder: (context, lmsSnap) {
            return StreamBuilder<List<Subtask>>(
              stream: _subtasks,
              builder: (context, subSnap) {
                if (!taskSnap.hasData || !lmsSnap.hasData) {
                  return const SizedBox.shrink();
                }
                final all = <TaskListItem>[
                  for (final t in taskSnap.data!) TaskListItem.task(t),
                  for (final e in lmsSnap.data!) TaskListItem.lms(e),
                ];
                return _buildList(context, all, subSnap.data ?? const [], width);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<TaskListItem> all,
    List<Subtask> subtasks,
    double width,
  ) {
    final now = widget.clock();
    final visible = all.where((i) => i.matches(_filter, widget.userId)).toList();
    if (visible.isEmpty) return _emptyFor(context, all);

    final Map<String, List<TaskListItem>> sections;
    final l10n = context.l10n;
    if (_filter == TaskFilter.done) {
      visible.sort((a, b) {
        final da = a.due, db = b.due;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      sections = {l10n.tasks_sectionDone: visible};
    } else {
      final grouped = groupByBucket(visible, now);
      sections = {
        for (final e in grouped.entries) _bucketTitle(l10n, e.key): e.value,
      };
    }

    final progress = <String, ({int done, int total})>{};
    for (final s in subtasks) {
      final cur = progress[s.taskId] ?? (done: 0, total: 0);
      progress[s.taskId] = (done: cur.done + (s.isDone ? 1 : 0), total: cur.total + 1);
    }

    return ListView(
      padding: contentPadding(width, bottom: 32),
      children: [
        for (final entry in sections.entries) ...[
          _SectionHeader(
            entry.key,
            trailing: Text(
              '${entry.value.length}',
              style: context.text.labelMedium!.tabular,
            ),
          ),
          ListGroup(
            dividerIndent: 48,
            children: [
              for (final item in entry.value) _rowFor(item, now, progress),
            ],
          ),
        ],
      ],
    );
  }

  Widget _rowFor(
    TaskListItem item,
    DateTime now,
    Map<String, ({int done, int total})> progress,
  ) {
    final editable = item.editableBy(widget.userId);
    String? author;
    if (item.task != null && item.task!.userId != widget.userId) {
      author = _group?.memberNames[item.task!.userId];
    }
    VoidCallback? onTap;
    if (item.isLms) {
      final url = item.lmsEvent!.url;
      if (url != null && url.isNotEmpty) onTap = () => _openLms(item.lmsEvent!);
    } else {
      onTap = () => _openEditor(taskId: item.id);
    }
    return TaskRow(
      key: ValueKey('task-row-${item.id}'),
      item: item,
      now: now,
      authorName: author,
      subtasks: item.task != null ? progress[item.id] : null,
      onToggle: editable ? () => _toggle(item) : null,
      onTap: onTap,
    );
  }

  String _bucketTitle(AppLocalizations l10n, TaskBucket b) {
    return switch (b) {
      TaskBucket.overdue => l10n.tasks_sectionOverdue,
      TaskBucket.today => l10n.tasks_sectionToday,
      TaskBucket.week => l10n.tasks_sectionWeek,
      TaskBucket.later => l10n.tasks_sectionLater,
      TaskBucket.noDate => l10n.tasks_sectionNoDate,
    };
  }

  Widget _emptyFor(BuildContext context, List<TaskListItem> all) {
    final l10n = context.l10n;
    void create() => _openEditor();
    switch (_filter) {
      case TaskFilter.all:
        if (all.any((i) => i.isDone)) {
          return EmptyState(
            title: l10n.tasks_allDoneTitle,
            message: l10n.tasks_allDoneMessage,
            actionLabel: l10n.tasks_newTask,
            onAction: create,
          );
        }
        return EmptyState(
          title: l10n.tasks_emptyTitle,
          message: l10n.tasks_emptyMessage,
          actionLabel: l10n.tasks_newTask,
          onAction: create,
        );
      case TaskFilter.mine:
        return EmptyState(
          title: l10n.tasks_emptyMineTitle,
          message: l10n.tasks_emptyMineMessage,
          actionLabel: l10n.tasks_newTask,
          onAction: create,
        );
      case TaskFilter.group:
        return EmptyState(
          title: l10n.tasks_emptyGroupTitle,
          message: l10n.tasks_emptyGroupMessage,
          actionLabel: l10n.tasks_newTask,
          onAction: create,
        );
      case TaskFilter.lms:
        return EmptyState(
          title: l10n.tasks_emptyLmsTitle,
          message: l10n.tasks_emptyLmsMessage,
        );
      case TaskFilter.done:
        return EmptyState(
          title: l10n.tasks_emptyDoneTitle,
          message: l10n.tasks_emptyDoneMessage,
        );
    }
  }
}

/// Section heading above a group of task rows. No horizontal padding of its
/// own: the list already sits in the content column, so the heading starts
/// at the same x as the row group.
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader(this.title, {required this.trailing});

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
          trailing,
        ],
      ),
    );
  }
}
