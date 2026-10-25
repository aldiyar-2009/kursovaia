import 'package:studyplan/core/database/app_database.dart';

/// Due-date buckets of the task list, in display order.
enum TaskBucket { overdue, today, week, later, noDate }

/// Filters of the task list.
enum TaskFilter { all, mine, group, lms, done }

/// Puts a due date into a bucket relative to [now].
///
/// overdue: before [now]; today: rest of today; week: the next 7 days after
/// today; later: anything after that; noDate: no due date.
TaskBucket bucketFor(DateTime? due, DateTime now) {
  if (due == null) return TaskBucket.noDate;
  if (due.isBefore(now)) return TaskBucket.overdue;
  final startTomorrow = DateTime(now.year, now.month, now.day + 1);
  if (due.isBefore(startTomorrow)) return TaskBucket.today;
  final weekEnd = DateTime(now.year, now.month, now.day + 8);
  if (due.isBefore(weekEnd)) return TaskBucket.week;
  return TaskBucket.later;
}

/// One row of the task list: either a local/group task or an LMS deadline.
class TaskListItem {
  final Task? task;
  final LmsEvent? lmsEvent;

  const TaskListItem.task(Task this.task) : lmsEvent = null;
  const TaskListItem.lms(LmsEvent this.lmsEvent) : task = null;

  bool get isLms => lmsEvent != null;
  bool get isGroup => task?.isGroup ?? false;

  String get id => task?.id ?? lmsEvent!.id;
  String get title => task?.title ?? lmsEvent!.title;

  bool get isDone =>
      task != null ? task!.status == 'completed' : lmsEvent!.isDone;

  DateTime? get due {
    if (task != null) {
      final d = task!.dueDate;
      return d == null ? null : DateTime.fromMillisecondsSinceEpoch(d.toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(lmsEvent!.startsAt.toInt());
  }

  /// Subject of a task or course of an LMS deadline.
  String? get context => task != null ? task!.subjectTitle : lmsEvent!.courseTitle;

  /// 1 high, 2 medium, 3 normal; LMS deadlines have no priority.
  int get priority => task?.priority ?? 3;

  /// Whether [userId] may change this item. Group tasks of other members are
  /// read-only (the server rejects changes to rows owned by someone else).
  bool editableBy(String userId) => isLms || task!.userId == userId;

  bool matches(TaskFilter filter, String userId) {
    switch (filter) {
      case TaskFilter.all:
        return !isDone;
      case TaskFilter.mine:
        return !isDone && !isLms && !isGroup && task!.userId == userId;
      case TaskFilter.group:
        return !isDone && isGroup;
      case TaskFilter.lms:
        return !isDone && isLms;
      case TaskFilter.done:
        return isDone;
    }
  }
}

/// Orders items inside a bucket: by due date, then priority, then title.
int compareItems(TaskListItem a, TaskListItem b) {
  final da = a.due, db = b.due;
  if (da != null && db != null) {
    final c = da.compareTo(db);
    if (c != 0) return c;
  }
  final p = a.priority.compareTo(b.priority);
  if (p != 0) return p;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Groups [items] into non-empty buckets in display order.
Map<TaskBucket, List<TaskListItem>> groupByBucket(
  Iterable<TaskListItem> items,
  DateTime now,
) {
  final result = <TaskBucket, List<TaskListItem>>{};
  for (final item in items) {
    result.putIfAbsent(bucketFor(item.due, now), () => []).add(item);
  }
  for (final list in result.values) {
    list.sort(compareItems);
  }
  return {
    for (final b in TaskBucket.values)
      if (result[b] != null) b: result[b]!,
  };
}
