import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/chat_dao.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/utils/uuid_util.dart';

class GroupChatScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String userName;
  final String userRole;
  final String groupId;

  const GroupChatScreen({
    super.key,
    required this.db,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.groupId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late final ChatDao _chatDao;
  late final TaskDao _taskDao;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatDao = ChatDao(widget.db);
    _taskDao = TaskDao(widget.db);
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _chatDao.insertMessage(
      ChatMessagesCompanion.insert(
        id: UuidUtil.generate(),
        groupId: widget.groupId,
        senderId: widget.userId,
        senderName: widget.userName,
        content: text,
        createdAt: BigInt.from(now),
        syncStatus: const drift.Value('pending_create'),
      ),
    );
    _msgController.clear();
  }

  void _acceptHomework(String taskId, String title, int? dueDate) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _taskDao.insertTask(
      TasksCompanion.insert(
        id: UuidUtil.generate(),
        userId: widget.userId,
        title: title,
        dueDate: drift.Value(dueDate != null ? BigInt.from(dueDate) : null),
        sourceTaskId: drift.Value(taskId),
        updatedAt: BigInt.from(now),
        syncStatus: const drift.Value('pending_create'),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Задание добавлено в ваши дедлайны!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chatDao.watchMessages(widget.groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'Сообщений пока нет',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == widget.userId;

                  if (msg.messageType == 'homework') {
                    return _buildHomeworkCard(msg);
                  } else if (msg.messageType == 'schedule_update') {
                    return _buildScheduleUpdateCard(msg);
                  }

                  return _buildTextMessage(msg, isMe);
                },
              );
            },
          ),
        ),
        // Headman actions (Homework & Schedule Update)
        if (widget.userRole == 'headman')
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.assignment_add, size: 16, color: AppColors.warning),
                  label: const Text('Опубликовать ДЗ', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                  backgroundColor: AppColors.elevated,
                  onPressed: _showPublishHomeworkDialog,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.accentCyan),
                  label: const Text('Перенос / Замена пары', style: TextStyle(fontSize: 11, color: AppColors.accentCyan)),
                  backgroundColor: AppColors.elevated,
                  onPressed: _showPublishScheduleUpdateDialog,
                ),
              ],
            ),
          ),
        // Input bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(
                    hintText: 'Написать сообщение в группу...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextMessage(ChatMessage msg, bool isMe) {
    final isPending = msg.syncStatus != 'synced';
    final timeStr = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(msg.createdAt.toInt()),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? AppColors.accent : AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                msg.senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isPending ? Icons.schedule_rounded : Icons.done_all_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkCard(ChatMessage msg) {
    Map<String, dynamic> payload = {};
    if (msg.payloadJson != null) {
      try {
        payload = jsonDecode(msg.payloadJson!);
      } catch (_) {}
    }

    final title = payload['title'] as String? ?? msg.content;
    final dueDateNum = payload['due_date'] as num?;
    final taskId = (payload['task_id'] as String?) ?? msg.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              const Text(
                'ДОМАШНЕЕ ЗАДАНИЕ ОТ СТАРОСТЫ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning.withValues(alpha: 0.15),
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.add_task_rounded, size: 16),
            label: const Text('Принять в свой список дедлайнов', style: TextStyle(fontSize: 12)),
            onPressed: () => _acceptHomework(taskId, title, dueDateNum?.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleUpdateCard(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notification_important_outlined, size: 16, color: AppColors.accentCyan),
              const SizedBox(width: 6),
              const Text(
                'ИЗМЕНЕНИЕ В РАСПИСАНИИ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.content,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  void _showPublishHomeworkDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.assignment_add, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text('Опубликовать ДЗ для группы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название задания *',
                    hintText: 'Лабораторная работа №3',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Описание задания',
                    hintText: 'Задания 1-12, сдать в PDF...',
                  ),
                ),
                const SizedBox(height: 14),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.warning),
                  label: Text(
                    dueDate != null ? DateFormat('d MMM, HH:mm').format(dueDate!) : 'Указать срок сдачи',
                    style: TextStyle(
                      fontSize: 12,
                      color: dueDate != null ? AppColors.warning : AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: AppColors.elevated,
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 3)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.black),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final now = DateTime.now().millisecondsSinceEpoch;
                final taskId = UuidUtil.generate();
                final messageId = UuidUtil.generate();

                final payload = {
                  'task_id': taskId,
                  'title': title,
                  'description': descController.text.trim(),
                  'due_date': dueDate?.millisecondsSinceEpoch,
                  'priority': 1,
                };

                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);

                // 1. Post to group chat
                await _chatDao.insertMessage(
                  ChatMessagesCompanion.insert(
                    id: messageId,
                    groupId: widget.groupId,
                    senderId: widget.userId,
                    senderName: widget.userName,
                    messageType: const drift.Value('homework'),
                    content: title,
                    payloadJson: drift.Value(jsonEncode(payload)),
                    createdAt: BigInt.from(now),
                    syncStatus: const drift.Value('pending_create'),
                  ),
                );

                // 2. Also register as a group task in local DB
                await _taskDao.insertTask(
                  TasksCompanion.insert(
                    id: taskId,
                    userId: widget.userId,
                    groupId: drift.Value(widget.groupId),
                    title: title,
                    description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                    dueDate: drift.Value(dueDate != null ? BigInt.from(dueDate!.millisecondsSinceEpoch) : null),
                    priority: const drift.Value(1),
                    isGroup: const drift.Value(true),
                    updatedAt: BigInt.from(now),
                    syncStatus: const drift.Value('pending_create'),
                  ),
                );

                messenger.showSnackBar(
                  const SnackBar(content: Text('Домашнее задание опубликовано в чате группы')),
                );
              },
              child: const Text('Опубликовать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublishScheduleUpdateDialog() {
    final updateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_calendar_rounded, color: AppColors.accentCyan, size: 22),
            SizedBox(width: 8),
            Text('Изменение в расписании', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: updateController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Текст объявления',
            hintText: 'Например: В пятницу пара «Компьютерные сети» перенесена в Ауд. 304...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final text = updateController.text.trim();
              if (text.isEmpty) return;

              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);

              final now = DateTime.now().millisecondsSinceEpoch;
              await _chatDao.insertMessage(
                ChatMessagesCompanion.insert(
                  id: UuidUtil.generate(),
                  groupId: widget.groupId,
                  senderId: widget.userId,
                  senderName: widget.userName,
                  messageType: const drift.Value('schedule_update'),
                  content: text,
                  isPinned: const drift.Value(true),
                  createdAt: BigInt.from(now),
                  syncStatus: const drift.Value('pending_create'),
                ),
              );

              messenger.showSnackBar(
                const SnackBar(content: Text('Изменение в расписании опубликовано')),
              );
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }
}
