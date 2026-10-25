import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/tasks/domain/task_list_item.dart';

/// One row of the task list: completion circle, title and a quiet meta line
/// (due, subject or course, labels). Place inside a `ListGroup`.
class TaskRow extends StatelessWidget {
  final TaskListItem item;
  final DateTime now;

  /// Null makes the completion circle read-only (group task of another member).
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  /// Shown for group tasks of other members when the name is known.
  final String? authorName;

  /// Number of subtasks done / total; hidden when total is 0.
  final ({int done, int total})? subtasks;

  const TaskRow({
    super.key,
    required this.item,
    required this.now,
    this.onToggle,
    this.onTap,
    this.authorName,
    this.subtasks,
  });

  String _formatDue(BuildContext context, DateTime due) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (item.isDone) return DateFormat('d MMM', locale).format(due);
    switch (bucketFor(due, now)) {
      case TaskBucket.today:
        return DateFormat.Hm(locale).format(due);
      case TaskBucket.week:
        return DateFormat('EEE, HH:mm', locale).format(due);
      case TaskBucket.overdue:
      case TaskBucket.later:
      case TaskBucket.noDate:
        return due.year == now.year
            ? DateFormat('d MMM, HH:mm', locale).format(due)
            : DateFormat('d MMM y', locale).format(due);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final due = item.due;
    final overdue = !item.isDone && due != null && due.isBefore(now);
    final metaStyle = context.text.bodySmall!.tabular;

    final meta = <Widget>[
      if (!item.isDone && item.priority < 3)
        _PriorityDot(
          color: item.priority == 1 ? p.danger : p.warning,
          label: item.priority == 1 ? l10n.tasks_priorityHigh : l10n.tasks_priorityMedium,
        ),
      if (due != null)
        Text(
          _formatDue(context, due),
          style: metaStyle.copyWith(color: overdue ? p.danger : p.textSecondary),
        ),
      if (item.context != null && item.context!.isNotEmpty)
        Text(
          item.context!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
      if (subtasks != null && subtasks!.total > 0)
        Text(
          l10n.tasks_subtaskProgress(subtasks!.done, subtasks!.total),
          style: metaStyle,
        ),
      if (authorName != null)
        Text(
          l10n.tasks_author(authorName!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
      if (item.isLms) StatusLabel(text: l10n.tasks_labelLms, tone: StatusTone.neutral),
      if (item.isGroup) StatusLabel(text: l10n.tasks_labelGroup, tone: StatusTone.neutral),
    ];

    final hasLink = item.isLms && (item.lmsEvent!.url?.isNotEmpty ?? false);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckCircle(
              key: ValueKey('task-check-${item.id}'),
              done: item.isDone,
              onPressed: onToggle,
              tooltip: item.isDone ? l10n.tasks_markNotDone : l10n.tasks_markDone,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium!.copyWith(
                        color: item.isDone ? p.textTertiary : p.textPrimary,
                        decoration: item.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: p.textTertiary,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: meta,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasLink) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: p.textTertiary,
                  semanticLabel: l10n.tasks_openLink,
                ),
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

class _PriorityDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PriorityDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Round completion control: hollow when open, filled with a check when done.
/// 44 px hit area around a 20 px circle.
class _CheckCircle extends StatelessWidget {
  final bool done;
  final VoidCallback? onPressed;
  final String tooltip;

  const _CheckCircle({
    super.key,
    required this.done,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? (enabled ? p.primary : p.textTertiary) : Colors.transparent,
        border: done
            ? null
            : Border.all(
                color: enabled ? p.textTertiary : p.border,
                width: 1.5,
              ),
      ),
      child: done ? Icon(Icons.check, size: 14, color: p.onPrimary) : null,
    );
    return Semantics(
      checked: done,
      enabled: enabled,
      button: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: enabled
            ? IconButton(
                onPressed: onPressed,
                tooltip: tooltip,
                padding: EdgeInsets.zero,
                icon: circle,
              )
            : Center(child: circle),
      ),
    );
  }
}
