import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/services/file_storage_service.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/utils/uuid_util.dart';

class TaskDetailBottomSheet extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String? initialSubjectId;
  final String? initialSubjectTitle;
  final String? existingTaskId;

  const TaskDetailBottomSheet({
    super.key,
    required this.db,
    required this.userId,
    this.initialSubjectId,
    this.initialSubjectTitle,
    this.existingTaskId,
  });

  static Future<void> show(
    BuildContext context, {
    required AppDatabase db,
    required String userId,
    String? initialSubjectId,
    String? initialSubjectTitle,
    String? existingTaskId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailBottomSheet(
        db: db,
        userId: userId,
        initialSubjectId: initialSubjectId,
        initialSubjectTitle: initialSubjectTitle,
        existingTaskId: existingTaskId,
      ),
    );
  }

  @override
  State<TaskDetailBottomSheet> createState() => _TaskDetailBottomSheetState();
}

class _TaskDetailBottomSheetState extends State<TaskDetailBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subtaskController = TextEditingController();

  DateTime? _dueDate;
  int _priority = 2; // P2 by default
  String? _selectedSubjectId;
  String? _selectedSubjectTitle;
  final bool _isGroup = false;

  final List<String> _subtasks = [];
  final List<({String name, String path, int size})> _attachedFiles = [];
  final FileStorageService _fileService = FileStorageService();

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _selectedSubjectTitle = widget.initialSubjectTitle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _pickFile() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      final file = File(result.first.path!);
      final saved = await _fileService.saveFile(file);
      setState(() {
        _attachedFiles.add((
          name: saved.fileName,
          path: saved.relativePath,
          size: saved.fileSize,
        ));
      });
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 2)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.accent,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

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
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _subtasks.add(text);
        _subtaskController.clear();
      });
    }
  }

  void _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи или заметки')),
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final taskId = widget.existingTaskId ?? UuidUtil.generate();
    final taskDao = TaskDao(widget.db);

    await taskDao.insertTask(
      TasksCompanion.insert(
        id: taskId,
        userId: widget.userId,
        title: title,
        description: drift.Value(_descController.text.trim().isEmpty ? null : _descController.text.trim()),
        subjectId: drift.Value(_selectedSubjectId),
        subjectTitle: drift.Value(_selectedSubjectTitle),
        dueDate: drift.Value(_dueDate != null ? BigInt.from(_dueDate!.millisecondsSinceEpoch) : null),
        priority: drift.Value(_priority),
        isGroup: drift.Value(_isGroup),
        updatedAt: BigInt.from(now),
        syncStatus: const drift.Value('pending_create'),
      ),
    );

    // Save subtasks
    for (int i = 0; i < _subtasks.length; i++) {
      await taskDao.insertSubtask(
        SubtasksCompanion.insert(
          id: UuidUtil.generate(),
          taskId: taskId,
          userId: widget.userId,
          title: _subtasks[i],
          position: drift.Value(i),
          updatedAt: BigInt.from(now),
          syncStatus: const drift.Value('pending_create'),
        ),
      );
    }

    // Save attachments metadata
    for (final att in _attachedFiles) {
      await widget.db.into(widget.db.attachments).insert(
            AttachmentsCompanion.insert(
              id: UuidUtil.generate(),
              taskId: drift.Value(taskId),
              fileName: att.name,
              relativePath: att.path,
              fileSize: BigInt.from(att.size),
              createdAt: BigInt.from(now),
            ),
          );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дедлайн сохранен и синхронизируется')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedSubjectTitle != null
                      ? 'Дедлайн: $_selectedSubjectTitle'
                      : 'Новая задача / дедлайн',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название дедлайна или заметки *',
                hintText: 'Например, Лабораторная работа №3',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Подробное описание / заметка (необязательно)',
                hintText: 'Задания 1-12, оформить в PDF...',
              ),
            ),
            const SizedBox(height: 16),
            // Controls row (Date, Priority, Subject)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.accentCyan),
                  label: Text(
                    _dueDate != null ? DateFormat('d MMM, HH:mm').format(_dueDate!) : 'Указать срок (дата/время)',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dueDate != null ? AppColors.accentCyan : AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: AppColors.elevated,
                  onPressed: _pickDate,
                ),
                ActionChip(
                  avatar: Icon(Icons.flag_outlined, size: 16, color: AppColors.priority(_priority)),
                  label: Text(
                    'Приоритет: P$_priority',
                    style: TextStyle(fontSize: 12, color: AppColors.priority(_priority)),
                  ),
                  backgroundColor: AppColors.elevated,
                  onPressed: () {
                    setState(() {
                      _priority = _priority == 3 ? 1 : _priority + 1;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.accent),
                  label: Text(
                    _attachedFiles.isEmpty ? 'Прикрепить файл' : 'Файлов: ${_attachedFiles.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _attachedFiles.isNotEmpty ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: AppColors.elevated,
                  onPressed: _pickFile,
                ),
              ],
            ),
            if (_attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._attachedFiles.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.accentCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f.name,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(f.size / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            // Checklist block
            const Text(
              'Чек-лист подзадач',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    decoration: const InputDecoration(
                      hintText: 'Добавить пункт чек-листа...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.elevated),
                  icon: const Icon(Icons.add, color: AppColors.accent),
                  onPressed: _addSubtask,
                ),
              ],
            ),
            if (_subtasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._subtasks.map((st) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(st, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveTask,
              child: const Text('Сохранить дедлайн'),
            ),
          ],
        ),
      ),
    );
  }
}
