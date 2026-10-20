import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';

class TaskDao {
  final AppDatabase db;
  TaskDao(this.db);

  Stream<List<Task>> watchTasks({
    required String userId,
    String? subjectId,
    String? groupId,
    String? status,
  }) {
    return (db.select(db.tasks)
          ..where((t) {
            var predicate = t.isDeleted.equals(false) &
                (t.userId.equals(userId) |
                    (t.isGroup.equals(true) &
                        (groupId != null ? t.groupId.equals(groupId) : const Constant(false))));
            if (subjectId != null) {
              predicate = predicate & t.subjectId.equals(subjectId);
            }
            if (status != null) {
              predicate = predicate & t.status.equals(status);
            }
            return predicate;
          })
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.dueDate),
          ]))
        .watch();
  }

  Stream<List<Subtask>> watchSubtasks(String taskId) {
    return (db.select(db.subtasks)
          ..where((t) => t.taskId.equals(taskId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<void> insertTask(TasksCompanion task) {
    return db.into(db.tasks).insert(task);
  }

  Future<void> updateTask(TasksCompanion task) {
    return db.update(db.tasks).replace(task);
  }

  Future<void> toggleTaskStatus(String id, String currentStatus, int nowMs) {
    final newStatus = currentStatus == 'completed' ? 'in_progress' : 'completed';
    return (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(newStatus),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(BigInt.from(nowMs)),
      ),
    );
  }

  Future<void> softDeleteTask(String id, int nowMs) {
    return (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(BigInt.from(nowMs)),
      ),
    );
  }

  Future<void> insertSubtask(SubtasksCompanion subtask) {
    return db.into(db.subtasks).insert(subtask);
  }

  Future<void> toggleSubtask(String id, bool currentDone, int nowMs) {
    return (db.update(db.subtasks)..where((t) => t.id.equals(id))).write(
      SubtasksCompanion(
        isDone: Value(!currentDone),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(BigInt.from(nowMs)),
      ),
    );
  }
}
