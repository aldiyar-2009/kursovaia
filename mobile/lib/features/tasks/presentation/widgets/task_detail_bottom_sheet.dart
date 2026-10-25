import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/services/file_storage_service.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';

/// Create / edit sheet for a task: title, description, due date, subject,
/// priority, group publishing, subtasks and attachments.
///
/// Group tasks of other members open read-only.
class TaskDetailBottomSheet extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String? initialSubjectId;
  final String? initialSubjectTitle;
  final String? existingTaskId;

  /// The user's group; the «Опубликовать для группы» switch is shown only
  /// when this is not null.
  final String? groupId;
  final String? groupTitle;

  /// Group member names by user id, to show the author of group tasks.
  final Map<String, String> memberNames;

  const TaskDetailBottomSheet({
    super.key,
    required this.db,
    required this.userId,
    this.initialSubjectId,
    this.initialSubjectTitle,
    this.existingTaskId,
    this.groupId,
    this.groupTitle,
    this.memberNames = const {},
  });

  static Future<void> show(
    BuildContext context, {
    required AppDatabase db,
    required String userId,
    String? initialSubjectId,
    String? initialSubjectTitle,
    String? existingTaskId,
    String? groupId,
    String? groupTitle,
    Map<String, String> memberNames = const {},
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => TaskDetailBottomSheet(
        db: db,
        userId: userId,
        initialSubjectId: initialSubjectId,
        initialSubjectTitle: initialSubjectTitle,
        existingTaskId: existingTaskId,
        groupId: groupId,
        groupTitle: groupTitle,
        memberNames: memberNames,
      ),
    );
  }

  @override
  State<TaskDetailBottomSheet> createState() => _TaskDetailBottomSheetState();
}

class _SubtaskDraft {
  final String? id;
  String title;
  bool done;
  bool removed = false;
  final bool initialDone;

  _SubtaskDraft({this.id, required this.title, this.done = false}) : initialDone = done;
}

class _TaskDetailBottomSheetState extends State<TaskDetailBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subtaskController = TextEditingController();
  final FileStorageService _fileService = FileStorageService();

  late final TaskDao _taskDao = TaskDao(widget.db);

  Task? _existing;
  bool _loading = false;
  String? _titleError;

  DateTime? _dueDate;
  int _priority = 3;
  String? _subjectId;
  String? _subjectTitle;
  bool _isGroup = false;

  final List<_SubtaskDraft> _subtasks = [];
  List<Attachment> _savedAttachments = const [];
  final List<({String name, String path, int size})> _newAttachments = [];

  bool get _isEdit => widget.existingTaskId != null;
  bool get _readOnly => _existing != null && _existing!.userId != widget.userId;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
    _subjectTitle = widget.initialSubjectTitle;
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final db = widget.db;
    final id = widget.existingTaskId!;
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    final subs = await (db.select(db.subtasks)
          ..where((t) => t.taskId.equals(id) & t.isDeleted.equals(false))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.position)]))
        .get();
    final atts = await (db.select(db.attachments)..where((t) => t.taskId.equals(id))).get();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _existing = task;
      if (task != null) {
        _titleController.text = task.title;
        _descController.text = task.description ?? '';
        _dueDate = task.dueDate == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(task.dueDate!.toInt());
        _priority = task.priority.clamp(1, 3);
        _subjectId = task.subjectId;
        _subjectTitle = task.subjectTitle;
        _isGroup = task.isGroup;
      }
      _subtasks
        ..clear()
        ..addAll(subs.map((s) => _SubtaskDraft(id: s.id, title: s.title, done: s.isDone)));
      _savedAttachments = atts;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  String _locale(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      final saved = await _fileService.saveFile(File(result.first.path!));
      if (!mounted) return;
      setState(() {
        _newAttachments.add((name: saved.fileName, path: saved.relativePath, size: saved.fileSize));
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? DateTime(now.year, now.month, now.day + 1, 23, 59);
    final earliest = DateTime(now.year - 1, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(earliest) ? earliest : initial,
      firstDate: _dueDate != null && _dueDate!.isBefore(earliest) ? _dueDate! : earliest,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;
    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _pickSubject() async {
    final db = widget.db;
    final subjects = await (db.select(db.subjects)
          ..where((t) => t.userId.equals(widget.userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.title)]))
        .get();
    if (!mounted) return;
    final l10n = context.l10n;
    // Empty string = "no subject"; null = dialog dismissed.
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.tasks_subject),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(l10n.tasks_subjectNone),
          ),
          for (final s in subjects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s.id),
              child: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (chosen.isEmpty) {
        _subjectId = null;
        _subjectTitle = null;
      } else {
        final s = subjects.firstWhere((e) => e.id == chosen);
        _subjectId = s.id;
        _subjectTitle = s.title;
      }
    });
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(_SubtaskDraft(title: text));
      _subtaskController.clear();
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.tasks_titleRequired);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = widget.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nowBig = BigInt.from(now);
    final existing = _existing;
    final taskId = existing?.id ?? UuidUtil.generate();
    final publish = _isGroup && widget.groupId != null;
    final desc = _descController.text.trim();

    await db.transaction(() async {
      await db.into(db.tasks).insertOnConflictUpdate(TasksCompanion(
            id: drift.Value(taskId),
            userId: drift.Value(widget.userId),
            title: drift.Value(title),
            description: drift.Value(desc.isEmpty ? null : desc),
            subjectId: drift.Value(_subjectId),
            subjectTitle: drift.Value(_subjectTitle),
            dueDate: drift.Value(_dueDate == null ? null : BigInt.from(_dueDate!.millisecondsSinceEpoch)),
            priority: drift.Value(_priority),
            isGroup: drift.Value(publish),
            groupId: drift.Value(publish ? widget.groupId : null),
            updatedAt: drift.Value(nowBig),
            syncStatus: drift.Value(
              existing == null || existing.syncStatus == 'pending_create'
                  ? 'pending_create'
                  : 'pending_update',
            ),
          ));

      for (var i = 0; i < _subtasks.length; i++) {
        final s = _subtasks[i];
        if (s.id == null) {
          if (s.removed) continue;
          await _taskDao.insertSubtask(SubtasksCompanion.insert(
            id: UuidUtil.generate(),
            taskId: taskId,
            userId: widget.userId,
            title: s.title,
            isDone: drift.Value(s.done),
            position: drift.Value(i),
            updatedAt: nowBig,
            syncStatus: const drift.Value('pending_create'),
          ));
        } else if (s.removed) {
          await (db.update(db.subtasks)..where((t) => t.id.equals(s.id!))).write(SubtasksCompanion(
            isDeleted: const drift.Value(true),
            updatedAt: drift.Value(nowBig),
            syncStatus: const drift.Value('pending_delete'),
          ));
        } else if (s.done != s.initialDone) {
          await (db.update(db.subtasks)..where((t) => t.id.equals(s.id!))).write(SubtasksCompanion(
            isDone: drift.Value(s.done),
            updatedAt: drift.Value(nowBig),
            syncStatus: const drift.Value('pending_update'),
          ));
        }
      }

      for (final att in _newAttachments) {
        await db.into(db.attachments).insert(AttachmentsCompanion.insert(
              id: UuidUtil.generate(),
              taskId: drift.Value(taskId),
              fileName: att.name,
              relativePath: att.path,
              fileSize: BigInt.from(att.size),
              createdAt: nowBig,
            ));
      }
    });

    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.tasks_saved)));
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _taskDao.softDeleteTask(existing.id, DateTime.now().millisecondsSinceEpoch);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.tasks_deleted)));
  }

  String _formatDue(BuildContext context, DateTime d) => DateFormat(
        d.year == DateTime.now().year ? 'd MMMM, HH:mm' : 'd MMM y, HH:mm',
        _locale(context),
      ).format(d);

  String _formatSize(int bytes) => (bytes / 1024).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? l10n.tasks_sheetEdit : l10n.tasks_sheetNew,
                    style: context.text.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.tasks_close,
                  icon: Icon(Icons.close, color: p.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _readOnly ? _buildReadOnly(context) : _buildForm(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          text,
          style: context.text.labelMedium!.copyWith(color: context.palette.textSecondary),
        ),
      );

  Widget _buildForm(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;

    final properties = <Widget>[
      ListRow(
        title: l10n.tasks_due,
        onTap: _pickDate,
        trailing: _TrailingValue(
          children: [
            Flexible(
              child: Text(
                _dueDate == null ? l10n.tasks_dueNone : _formatDue(context, _dueDate!),
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium!.tabular.copyWith(
                  color: _dueDate == null ? p.textTertiary : p.textPrimary,
                ),
              ),
            ),
            if (_dueDate != null)
              IconButton(
                tooltip: l10n.tasks_dueClear,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _dueDate = null),
              ),
          ],
        ),
      ),
      ListRow(
        title: l10n.tasks_subject,
        onTap: _pickSubject,
        trailing: _TrailingValue(
          children: [
            Flexible(
              child: Text(
                _subjectTitle ?? l10n.tasks_subjectNone,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium!.copyWith(
                  color: _subjectTitle == null ? p.textTertiary : p.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const ListRowChevron(),
          ],
        ),
      ),
      if (widget.groupId != null)
        ListRow(
          key: const ValueKey('tasks-publish-group'),
          title: l10n.tasks_publishGroup,
          subtitle: widget.groupTitle != null
              ? l10n.tasks_publishGroupHint(widget.groupTitle!)
              : null,
          onTap: () => setState(() => _isGroup = !_isGroup),
          trailing: Switch(
            value: _isGroup,
            onChanged: (v) => setState(() => _isGroup = v),
          ),
        ),
    ];

    final visibleSubtasks = _subtasks.where((s) => !s.removed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _titleController,
          label: l10n.tasks_fieldTitle,
          hint: l10n.tasks_fieldTitleHint,
          errorText: _titleError,
          autofocus: !_isEdit,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _descController,
          label: l10n.tasks_fieldDescription,
          hint: l10n.tasks_fieldDescriptionHint,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        ListGroup(children: properties),
        _label(context, l10n.tasks_priority),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 1, label: Text(l10n.tasks_priorityHighShort)),
            ButtonSegment(value: 2, label: Text(l10n.tasks_priorityMediumShort)),
            ButtonSegment(value: 3, label: Text(l10n.tasks_priorityLowShort)),
          ],
          selected: {_priority},
          onSelectionChanged: (s) => setState(() => _priority = s.first),
        ),
        _label(context, l10n.tasks_subtasks),
        if (visibleSubtasks.isNotEmpty) ...[
          ListGroup(
            dividerIndent: 52,
            children: [
              for (final s in visibleSubtasks)
                _SubtaskRow(
                  title: s.title,
                  done: s.done,
                  onChanged: (v) => setState(() => s.done = v),
                  onRemove: () => setState(() => s.removed = true),
                  removeTooltip: l10n.tasks_subtaskRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _subtaskController,
                hint: l10n.tasks_subtaskHint,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _addSubtask,
                child: Text(l10n.tasks_subtaskAdd),
              ),
            ),
          ],
        ),
        _label(context, l10n.tasks_attachments),
        if (_savedAttachments.isNotEmpty || _newAttachments.isNotEmpty) ...[
          ListGroup(
            children: [
              for (final a in _savedAttachments)
                _attachmentRow(context, a.fileName, a.fileSize.toInt()),
              for (final a in _newAttachments) _attachmentRow(context, a.name, a.size),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (kIsWeb)
          Text(l10n.tasks_attachUnavailable, style: context.text.bodySmall)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(l10n.tasks_attach),
            ),
          ),
        const SizedBox(height: 32),
        FilledButton(
          key: const ValueKey('tasks-save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _save,
          child: Text(l10n.common_save),
        ),
        if (_existing != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: p.danger,
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: _delete,
            child: Text(l10n.tasks_deleteTask),
          ),
        ],
      ],
    );
  }

  Widget _attachmentRow(BuildContext context, String name, int size) => ListRow(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: name,
        trailing: Text(context.l10n.tasks_fileSizeKb(_formatSize(size))),
      );

  Widget _buildReadOnly(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final task = _existing!;
    final author = widget.memberNames[task.userId];
    final rows = <Widget>[
      if (_dueDate != null)
        ListRow(
          title: l10n.tasks_due,
          trailing: _TrailingValue(children: [
            Flexible(child: Text(_formatDue(context, _dueDate!), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      if (_subjectTitle != null)
        ListRow(
          title: l10n.tasks_subject,
          trailing: _TrailingValue(children: [
            Flexible(child: Text(_subjectTitle!, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      if (author != null) ListRow(title: l10n.tasks_author(author)),
    ];
    final subs = _subtasks.where((s) => !s.removed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(task.title, style: context.text.titleMedium),
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description!,
            style: context.text.bodyMedium!.copyWith(color: p.textSecondary),
          ),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 24),
          ListGroup(children: rows),
        ],
        if (subs.isNotEmpty) ...[
          _label(context, l10n.tasks_subtasks),
          ListGroup(
            dividerIndent: 52,
            children: [
              for (final s in subs) _SubtaskRow(title: s.title, done: s.done),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.tasks_readOnlyHint, style: context.text.bodySmall),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Value + control on the right of a property row. Caps its width so long
/// values ellipsize instead of overflowing on narrow phones.
class _TrailingValue extends StatelessWidget {
  final List<Widget> children;

  const _TrailingValue({required this.children});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.6;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(120, 320)),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  final String title;
  final bool done;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  const _SubtaskRow({
    required this.title,
    required this.done,
    this.onChanged,
    this.onRemove,
    this.removeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Checkbox(
            value: done,
            onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          ),
          Expanded(
            child: Text(
              title,
              style: context.text.bodyMedium!.copyWith(
                color: done ? p.textTertiary : p.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: p.textTertiary,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: removeTooltip,
              icon: Icon(Icons.close, size: 18, color: p.textTertiary),
              onPressed: onRemove,
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}
