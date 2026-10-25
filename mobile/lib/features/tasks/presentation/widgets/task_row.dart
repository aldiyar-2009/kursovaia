import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/due_format.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final due = item.due;
    final overdue = !item.isDone && due != null && due.isBefore(now);
    final metaStyle = context.text.bodySmall!.tabular;
    // Same wording as Home's deadline rows.
    final dueText = due == null ? null : formatDue(context, due, now: now);
    final hasLink = item.isLms && (item.lmsEvent!.url?.isNotEmpty ?? false);

    // What a screen reader announces for the row: "title, due, status".
    final summary = [
      item.title,
      if (dueText != null) l10n.tasks_rowDue(dueText),
      item.isDone
          ? l10n.tasks_statusDone
          : overdue
              ? l10n.tasks_statusOverdue
              : l10n.tasks_statusOpen,
      if (hasLink) l10n.tasks_openLink,
    ].join(', ');

    final meta = <Widget>[
      if (!item.isDone && item.priority < 3)
        _PriorityDot(
          color: item.priority == 1 ? p.danger : p.warning,
          label: item.priority == 1 ? l10n.tasks_priorityHigh : l10n.tasks_priorityMedium,
        ),
      if (dueText != null)
        Text(
          dueText,
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

    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            child: Icon(Icons.open_in_new, size: 16, color: p.textTertiary),
          ),
        ],
      ],
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Its own semantics node: "mark as done, <title>", checked state.
            _CheckCircle(
              key: ValueKey('task-check-${item.id}'),
              done: item.isDone,
              onPressed: onToggle,
              tooltip: item.isDone ? l10n.tasks_markNotDone : l10n.tasks_markDone,
              semanticLabel:
                  '${item.isDone ? l10n.tasks_markNotDone : l10n.tasks_markDone}, '
                  '${item.title}',
            ),
            // The rest of the row is one node that opens the details.
            Expanded(
              child: Semantics(
                key: ValueKey('task-open-${item.id}'),
                container: true,
                button: onTap != null,
                label: summary,
                onTap: onTap,
                excludeSemantics: true,
                child: details,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      // Semantics come from the nodes above, not from the ink well.
      child: InkWell(onTap: onTap, excludeFromSemantics: true, child: row),
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
  final String semanticLabel;

  const _CheckCircle({
    super.key,
    required this.done,
    required this.onPressed,
    required this.tooltip,
    required this.semanticLabel,
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
      container: true,
      checked: done,
      enabled: enabled,
      button: enabled,
      label: semanticLabel,
      onTap: onPressed,
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
