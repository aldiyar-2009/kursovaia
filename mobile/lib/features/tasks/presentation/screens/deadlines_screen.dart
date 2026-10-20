import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/features/tasks/presentation/widgets/task_detail_bottom_sheet.dart';

class DeadlinesScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String? groupId;
  final bool isHeadman;

  const DeadlinesScreen({
    super.key,
    required this.db,
    required this.userId,
    this.groupId,
    this.isHeadman = false,
  });

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  late final TaskDao _taskDao;
  final TextEditingController _inboxController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedSubjectId;
  String _statusFilter = 'all'; // all, pending, completed
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _taskDao = TaskDao(widget.db);
  }

  @override
  void dispose() {
    _inboxController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  void _addQuickTask() async {
    final title = _inboxController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _taskDao.insertTask(
      TasksCompanion.insert(
        id: UuidUtil.generate(),
        userId: widget.userId,
        title: title,
        updatedAt: BigInt.from(now),
        syncStatus: const drift.Value('pending_create'),
      ),
    );
    _inboxController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick Inbox bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inboxController,
                      decoration: const InputDecoration(
                        hintText: 'Быстрая задача или заметка...',
                        prefixIcon: Icon(Icons.add_task_rounded, size: 20, color: AppColors.textSecondary),
                      ),
                      onSubmitted: (_) => _addQuickTask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _showSearch ? AppColors.plate(AppColors.accentCyan, 0.2) : AppColors.elevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.search_rounded, color: _showSearch ? AppColors.accentCyan : AppColors.textSecondary),
                    tooltip: 'Поиск по задачам',
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.elevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.tune_rounded, color: AppColors.accentCyan),
                    tooltip: 'Подробный дедлайн (дата, файлы, подзадачи)',
                    onPressed: () {
                      TaskDetailBottomSheet.show(
                        context,
                        db: widget.db,
                        userId: widget.userId,
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                    onPressed: _addQuickTask,
                  ),
                ],
              ),
              if (_showSearch) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию или описанию...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.accentCyan),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        // Filter Chips by subjects & status
        StreamBuilder<List<Subject>>(
          stream: (widget.db.select(widget.db.subjects)
                ..where((t) => t.userId.equals(widget.userId) & t.isDeleted.equals(false)))
              .watch(),
          builder: (context, snapshot) {
            final subjects = snapshot.data ?? [];

            return SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Все задачи'),
                    selected: _statusFilter == 'all' && _selectedSubjectId == null,
                    onSelected: (_) => setState(() {
                      _statusFilter = 'all';
                      _selectedSubjectId = null;
                    }),
                    backgroundColor: AppColors.elevated,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: (_statusFilter == 'all' && _selectedSubjectId == null) ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('В работе'),
                    selected: _statusFilter == 'pending',
                    onSelected: (_) => setState(() {
                      _statusFilter = _statusFilter == 'pending' ? 'all' : 'pending';
                    }),
                    backgroundColor: AppColors.elevated,
                    selectedColor: AppColors.warning,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _statusFilter == 'pending' ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Выполненные'),
                    selected: _statusFilter == 'completed',
                    onSelected: (_) => setState(() {
                      _statusFilter = _statusFilter == 'completed' ? 'all' : 'completed';
                    }),
                    backgroundColor: AppColors.elevated,
                    selectedColor: AppColors.success,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _statusFilter == 'completed' ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const VerticalDivider(color: AppColors.border, indent: 8, endIndent: 8),
                  const SizedBox(width: 8),
                  ...subjects.map((sub) {
                    final isSelected = _selectedSubjectId == sub.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(sub.title),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedSubjectId = isSelected ? null : sub.id),
                        backgroundColor: AppColors.elevated,
                        selectedColor: AppColors.fromHex(sub.colorHex),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const Divider(color: AppColors.border, height: 1),
        // Deadlines List
        Expanded(
          child: StreamBuilder<List<Task>>(
            stream: _taskDao.watchTasks(
              userId: widget.userId,
              groupId: widget.groupId,
              subjectId: _selectedSubjectId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              var tasks = snapshot.data ?? [];

              // Apply status filter
              if (_statusFilter == 'pending') {
                tasks = tasks.where((t) => t.status != 'completed').toList();
              } else if (_statusFilter == 'completed') {
                tasks = tasks.where((t) => t.status == 'completed').toList();
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                tasks = tasks.where((t) =>
                  t.title.toLowerCase().contains(q) ||
                  (t.description?.toLowerCase().contains(q) ?? false)
                ).toList();
              }

              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.done_all_rounded, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 14),
                      const Text('Все дедлайны закрыты!', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Добавьте задачу через поле выше', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final isDone = task.status == 'completed';
                  final priorityColor = AppColors.priority(task.priority);

                  return Dismissible(
                    key: Key(task.id),
                    background: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AppColors.success),
                    ),
                    secondaryBackground: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline, color: AppColors.danger),
                    ),
                    onDismissed: (direction) {
                      final now = DateTime.now().millisecondsSinceEpoch;
                      if (direction == DismissDirection.startToEnd) {
                        _taskDao.toggleTaskStatus(task.id, task.status, now);
                      } else {
                        _taskDao.softDeleteTask(task.id, now);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: task.priority == 1 ? AppColors.danger.withValues(alpha: 0.6) : AppColors.border,
                          width: task.priority == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: Icon(
                              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isDone ? AppColors.success : AppColors.textMuted,
                            ),
                            onPressed: () {
                              final now = DateTime.now().millisecondsSinceEpoch;
                              _taskDao.toggleTaskStatus(task.id, task.status, now);
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (task.isGroup)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.plate(AppColors.accentCyan),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Группа',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.plate(priorityColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'P${task.priority}',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor),
                                      ),
                                    ),
                                    if (task.dueDate != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('d MMM, HH:mm').format(
                                          DateTime.fromMillisecondsSinceEpoch(task.dueDate!.toInt()),
                                        ),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (task.description != null && task.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
