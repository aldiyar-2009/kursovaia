import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';

class SyncRepository {
  final AppDatabase db;
  final ApiClient apiClient;

  SyncRepository({required this.db, required this.apiClient});

  static const String _lastSyncedKey = 'studyplan_last_synced_at';

  Future<int> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncedKey) ?? 0;
  }

  Future<void> setLastSyncedAt(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedKey, timestamp);
  }

  Future<int> getPendingChangesCount(String userId) async {
    final pendingSubjects = await (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingLessons = await (db.select(db.lessons)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingTasks = await (db.select(db.tasks)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingSubtasks = await (db.select(db.subtasks)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingMessages = await (db.select(db.chatMessages)
          ..where((t) => t.senderId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();

    return pendingSubjects.length +
        pendingLessons.length +
        pendingTasks.length +
        pendingSubtasks.length +
        pendingMessages.length;
  }

  /// Pushes local pending changes and pulls latest server records
  Future<({int serverTime, int appliedCount})> syncWithServer(String userId) async {
    final lastSyncedAt = await getLastSyncedAt();

    // 1. Collect pending changes from Drift
    final pendingSubjects = await (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingLessons = await (db.select(db.lessons)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingTasks = await (db.select(db.tasks)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingSubtasks = await (db.select(db.subtasks)
          ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();
    final pendingMessages = await (db.select(db.chatMessages)
          ..where((t) => t.senderId.equals(userId) & t.syncStatus.isNotValue('synced')))
        .get();

    final payload = {
      'last_synced_at': lastSyncedAt,
      'changes': {
        'subjects': pendingSubjects.map((s) => {
              'id': s.id,
              'title': s.title,
              'teacher_name': s.teacherName,
              'color_hex': s.colorHex,
              'is_deleted': s.isDeleted,
              'updated_at': s.updatedAt.toInt(),
            }).toList(),
        'lessons': pendingLessons.map((l) => {
              'id': l.id,
              'subject_id': l.subjectId,
              'day_of_week': l.dayOfWeek,
              'start_time': l.startTime,
              'end_time': l.endTime,
              'classroom': l.classroom,
              'lesson_type': l.lessonType,
              'topic': l.topic,
              'is_even_week': l.isEvenWeek,
              'specific_date': l.specificDate,
              'valid_from': l.validFrom,
              'valid_to': l.validTo,
              'is_cancelled': l.isCancelled,
              'is_deleted': l.isDeleted,
              'updated_at': l.updatedAt.toInt(),
            }).toList(),
        'tasks': pendingTasks.map((t) => {
              'id': t.id,
              'group_id': t.groupId,
              'subject_id': t.subjectId,
              'subject_title': t.subjectTitle,
              'title': t.title,
              'description': t.description,
              'due_date': t.dueDate?.toInt(),
              'priority': t.priority,
              'status': t.status,
              'is_group': t.isGroup,
              'source_message_id': t.sourceMessageId,
              'source_task_id': t.sourceTaskId,
              'is_deleted': t.isDeleted,
              'updated_at': t.updatedAt.toInt(),
            }).toList(),
        'subtasks': pendingSubtasks.map((st) => {
              'id': st.id,
              'task_id': st.taskId,
              'title': st.title,
              'is_done': st.isDone,
              'position': st.position,
              'is_deleted': st.isDeleted,
              'updated_at': st.updatedAt.toInt(),
            }).toList(),
        'chat_messages': pendingMessages.map((m) => {
              'id': m.id,
              'message_type': m.messageType,
              'content': m.content,
              'payload_json': m.payloadJson != null ? jsonDecode(m.payloadJson!) : null,
              'created_at': m.createdAt.toInt(),
            }).toList(),
      },
    };

    final response = await apiClient.dio.post('/sync', data: payload);
    final data = response.data as Map<String, dynamic>;
    final serverTime = data['server_time'] as int;
    final changes = data['changes'] as Map<String, dynamic>;

    // 2. Mark local pending items as synced in transaction
    await db.transaction(() async {
      // Subjects
      for (final s in pendingSubjects) {
        if (s.isDeleted) {
          await (db.delete(db.subjects)..where((t) => t.id.equals(s.id))).go();
        } else {
          await (db.update(db.subjects)..where((t) => t.id.equals(s.id))).write(
            const SubjectsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Lessons
      for (final l in pendingLessons) {
        if (l.isDeleted) {
          await (db.delete(db.lessons)..where((t) => t.id.equals(l.id))).go();
        } else {
          await (db.update(db.lessons)..where((t) => t.id.equals(l.id))).write(
            const LessonsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Tasks
      for (final t in pendingTasks) {
        if (t.isDeleted) {
          await (db.delete(db.tasks)..where((row) => row.id.equals(t.id))).go();
        } else {
          await (db.update(db.tasks)..where((row) => row.id.equals(t.id))).write(
            const TasksCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Subtasks
      for (final st in pendingSubtasks) {
        if (st.isDeleted) {
          await (db.delete(db.subtasks)..where((t) => t.id.equals(st.id))).go();
        } else {
          await (db.update(db.subtasks)..where((t) => t.id.equals(st.id))).write(
            const SubtasksCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Messages
      for (final m in pendingMessages) {
        await (db.update(db.chatMessages)..where((t) => t.id.equals(m.id))).write(
          const ChatMessagesCompanion(syncStatus: Value('synced')),
        );
      }

      // 3. Apply server changes (Last-Write-Wins pull)
      final serverSubjects = (changes['subjects'] as List<dynamic>? ?? []);
      for (final raw in serverSubjects) {
        final s = raw as Map<String, dynamic>;
        final isDeleted = s['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.subjects)..where((t) => t.id.equals(s['id']))).go();
        } else {
          await db.into(db.subjects).insertOnConflictUpdate(
                SubjectsCompanion(
                  id: Value(s['id']),
                  userId: Value(userId),
                  title: Value(s['title']),
                  teacherName: Value(s['teacher_name']),
                  colorHex: Value(s['color_hex']),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(s['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverLessons = (changes['lessons'] as List<dynamic>? ?? []);
      for (final raw in serverLessons) {
        final l = raw as Map<String, dynamic>;
        final isDeleted = l['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.lessons)..where((t) => t.id.equals(l['id']))).go();
        } else {
          await db.into(db.lessons).insertOnConflictUpdate(
                LessonsCompanion(
                  id: Value(l['id']),
                  subjectId: Value(l['subject_id']),
                  userId: Value(userId),
                  dayOfWeek: Value((l['day_of_week'] as num).toInt()),
                  startTime: Value(l['start_time']),
                  endTime: Value(l['end_time']),
                  classroom: Value(l['classroom']),
                  lessonType: Value(l['lesson_type'] ?? 'lecture'),
                  topic: Value(l['topic']),
                  isEvenWeek: Value(l['is_even_week']),
                  specificDate: Value(l['specific_date']),
                  validFrom: Value(l['valid_from']),
                  validTo: Value(l['valid_to']),
                  isCancelled: Value(l['is_cancelled'] == true),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(l['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverTasks = (changes['tasks'] as List<dynamic>? ?? []);
      for (final raw in serverTasks) {
        final t = raw as Map<String, dynamic>;
        final isDeleted = t['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.tasks)..where((e) => e.id.equals(t['id']))).go();
        } else {
          await db.into(db.tasks).insertOnConflictUpdate(
                TasksCompanion(
                  id: Value(t['id']),
                  userId: Value(t['user_id'] ?? userId),
                  groupId: Value(t['group_id']),
                  subjectId: Value(t['subject_id']),
                  subjectTitle: Value(t['subject_title']),
                  title: Value(t['title']),
                  description: Value(t['description']),
                  dueDate: Value(t['due_date'] != null ? BigInt.from(t['due_date'] as num) : null),
                  priority: Value((t['priority'] as num? ?? 3).toInt()),
                  status: Value(t['status'] ?? 'inbox'),
                  isGroup: Value(t['is_group'] == true),
                  sourceMessageId: Value(t['source_message_id']),
                  sourceTaskId: Value(t['source_task_id']),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(t['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverSubtasks = (changes['subtasks'] as List<dynamic>? ?? []);
      for (final raw in serverSubtasks) {
        final st = raw as Map<String, dynamic>;
        final isDeleted = st['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.subtasks)..where((e) => e.id.equals(st['id']))).go();
        } else {
          await db.into(db.subtasks).insertOnConflictUpdate(
                SubtasksCompanion(
                  id: Value(st['id']),
                  taskId: Value(st['task_id']),
                  userId: Value(userId),
                  title: Value(st['title']),
                  isDone: Value(st['is_done'] == true),
                  position: Value((st['position'] as num? ?? 0).toInt()),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(st['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverMessages = (changes['chat_messages'] as List<dynamic>? ?? []);
      for (final raw in serverMessages) {
        final m = raw as Map<String, dynamic>;
        await db.into(db.chatMessages).insertOnConflictUpdate(
              ChatMessagesCompanion(
                id: Value(m['id']),
                groupId: Value(m['group_id']),
                senderId: Value(m['sender_id']),
                senderName: Value(m['sender_name'] ?? 'Студент'),
                messageType: Value(m['message_type'] ?? 'text'),
                content: Value(m['content']),
                payloadJson: Value(m['payload_json'] != null ? jsonEncode(m['payload_json']) : null),
                isPinned: Value(m['is_pinned'] == true),
                createdAt: Value(BigInt.from(m['created_at'] as num)),
                syncStatus: const Value('synced'),
              ),
            );
      }
    });

    await setLastSyncedAt(serverTime);
    return (serverTime: serverTime, appliedCount: pendingSubjects.length + pendingLessons.length + pendingTasks.length);
  }
}
