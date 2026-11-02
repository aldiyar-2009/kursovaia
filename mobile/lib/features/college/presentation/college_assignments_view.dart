import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/due_format.dart';
import 'package:studyplan/core/utils/open_url.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/college/data/college_models.dart';
import 'package:studyplan/features/college/data/college_repository.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';

/// Id of the personal task made from a SmartNation assignment.
String assignmentTaskId(String userId, SnAssignment a) =>
    UuidUtil.stable(userId, 'sn-assignment:${a.id}');

/// «Колледж» filter of the Tasks tab: assignments from SmartNation, current
/// and past, with «open in SmartNation» and «add to my tasks».
class CollegeAssignmentsView extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// Null for guests.
  final CollegeRepository? repository;

  const CollegeAssignmentsView({
    super.key,
    required this.db,
    required this.userId,
    this.repository,
  });

  @override
  State<CollegeAssignmentsView> createState() => _CollegeAssignmentsViewState();
}

class _CollegeAssignmentsViewState extends State<CollegeAssignmentsView> {
  SnSnapshot? _snapshot;
  bool _loading = true;
  bool _past = false;

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
    final cached = await repo.cachedSnapshot();
    if (mounted && cached != null) setState(() => _snapshot = cached);
    final result = await repo.loadSnapshot(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _snapshot = result.snapshot ?? _snapshot;
      _loading = false;
    });
  }

  Future<void> _addToTasks(SnAssignment a) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final added = await TaskDao(widget.db).addExternalTask(
      id: assignmentTaskId(widget.userId, a),
      userId: widget.userId,
      title: a.title,
      subjectTitle: a.subject.isEmpty ? null : a.subject,
      description: a.url,
      due: a.expiresAt,
      priority: 1,
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          added ? l10n.college_assignmentAdded : l10n.college_assignmentExists,
        ),
      ),
    );
  }

  void _open(SnAssignment a, bool inTasks) {
    final l10n = context.l10n;
    showAppSheet<void>(
      context,
      title: a.title,
      primaryAction: a.isCurrent && !inTasks
          ? FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addToTasks(a);
              },
              child: Text(l10n.college_addToTasks),
            )
          : null,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.subject, style: sheetContext.text.labelLarge),
          const SizedBox(height: 8),
          if (a.expiresAt != null)
            Text(
              l10n.college_dueAt(formatDateTime(sheetContext, a.expiresAt!)),
              style: sheetContext.text.bodySmall,
            ),
          if (a.createdAt != null)
            Text(
              l10n.college_givenAt(formatDateTime(sheetContext, a.createdAt!)),
              style: sheetContext.text.bodySmall,
            ),
          if (a.status != null) ...[
            const SizedBox(height: 8),
            _status(sheetContext, a),
          ],
          if (a.result != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.college_result('${a.result}'),
              style: sheetContext.text.bodyMedium,
            ),
          ],
          if (a.url != null && a.url!.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => openExternalUrl(sheetContext, a.url),
              child: Text(l10n.college_openInSmartNation),
            ),
          ],
        ],
      ),
    );
  }

  Widget _status(BuildContext context, SnAssignment a) {
    final status = a.status ?? '';
    final overdue =
        a.isCurrent &&
        !a.isDone &&
        a.expiresAt != null &&
        a.expiresAt!.isBefore(DateTime.now());
    final tone = switch (status) {
      SnStatus.checked => StatusTone.success,
      SnStatus.onReview || SnStatus.done => StatusTone.neutral,
      _ => overdue ? StatusTone.danger : StatusTone.warning,
    };
    return StatusLabel(
      text: overdue && !a.isDone ? context.l10n.college_overdue : status,
      tone: tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.repository == null) {
      return EmptyState(
        title: l10n.college_gradesGuestTitle,
        message: l10n.college_gradesGuestMessage,
      );
    }
    final snap = _snapshot;
    if (snap == null) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(
              title: l10n.college_assignmentsEmpty,
              message: l10n.college_gradesEmptyMessage,
              actionLabel: l10n.college_refresh,
              onAction: () => _load(refresh: true),
            );
    }
    final current = snap.currentAssignments;
    final past = snap.pastAssignments;
    final list = _past ? past : current;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: ListView(
            padding: contentPadding(width, top: 12, bottom: 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SegmentedToggle<bool>(
                    expand: true,
                    segments: [
                      (false, l10n.college_assignmentsCurrent(current.length)),
                      (true, l10n.college_assignmentsPast(past.length)),
                    ],
                    value: _past,
                    onChanged: (v) => setState(() => _past = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.college_assignmentsEmpty,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium!.copyWith(
                      color: context.palette.textTertiary,
                    ),
                  ),
                )
              else
                StreamBuilder<Set<String>>(
                  stream: TaskDao(widget.db).watchExistingIds(
                    list.map((a) => assignmentTaskId(widget.userId, a)),
                  ),
                  builder: (context, snapIds) {
                    final inTasks = snapIds.data ?? const <String>{};
                    return ListGroup(
                      children: [
                        for (final a in list)
                          _row(
                            context,
                            a,
                            inTasks.contains(
                              assignmentTaskId(widget.userId, a),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, SnAssignment a, bool inTasks) {
    final l10n = context.l10n;
    final due = a.expiresAt;
    final subtitle = [
      if (a.subject.isNotEmpty) a.subject,
      if (due != null) formatDue(context, due),
      if (inTasks) l10n.college_inTasks,
    ].join(' · ');
    return ListRow(
      title: a.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: a.status == null ? const ListRowChevron() : _status(context, a),
      onTap: () => _open(a, inTasks),
    );
  }
}
