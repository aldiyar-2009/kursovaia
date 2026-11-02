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
            var predicate =
                t.isDeleted.equals(false) &
                (t.userId.equals(userId) |
                    (t.isGroup.equals(true) &
                        (groupId != null
                            ? t.groupId.equals(groupId)
                            : const Constant(false))));
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

  /// Personal task made from outside data (event, college assignment) with
  /// a stable [id]: returns false when it is already in the list. A task
  /// the user deleted earlier is restored.
  Future<bool> addExternalTask({
    required String id,
    required String userId,
    required String title,
    String? description,
    String? subjectTitle,
    DateTime? due,
    int priority = 2,
  }) async {
    final existing = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null && !existing.isDeleted) return false;
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    final row = TasksCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title.length > 255 ? title.substring(0, 255) : title),
      description: Value(description),
      subjectTitle: Value(subjectTitle),
      dueDate: Value(
        due == null ? null : BigInt.from(due.millisecondsSinceEpoch),
      ),
      priority: Value(priority),
      status: const Value('inbox'),
      isGroup: const Value(false),
      isDeleted: const Value(false),
      updatedAt: Value(now),
    );
    if (existing == null) {
      await db
          .into(db.tasks)
          .insert(row.copyWith(syncStatus: const Value('pending_create')));
    } else {
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
        row.copyWith(syncStatus: const Value('pending_update')),
      );
    }
    return true;
  }

  /// Ids among [ids] that are live tasks (to mark «already in the plan»).
  Stream<Set<String>> watchExistingIds(Iterable<String> ids) {
    final list = ids.toList();
    if (list.isEmpty) return Stream.value(const {});
    return (db.select(db.tasks)
          ..where((t) => t.id.isIn(list) & t.isDeleted.equals(false)))
        .watch()
        .map((rows) => {for (final r in rows) r.id});
  }

  Future<void> updateTask(TasksCompanion task) {
    return db.update(db.tasks).replace(task);
  }

  Future<void> toggleTaskStatus(String id, String currentStatus, int nowMs) {
    final newStatus = currentStatus == 'completed'
        ? 'in_progress'
        : 'completed';
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
