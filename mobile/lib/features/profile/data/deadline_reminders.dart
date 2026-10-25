import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/services/notification_service.dart';

/// A deadline that can get a local reminder.
typedef ReminderDeadline = ({String id, String title, DateTime dueDate});

/// Turns deadline reminders on and off: reads the user's upcoming deadlines
/// (own and group tasks not completed, LMS deadlines not done) from drift and
/// schedules / cancels local notifications for them.
class DeadlineReminders {
  static const prefsKey = 'settings.deadline_reminders';

  final AppDatabase db;
  final NotificationService notifications;

  DeadlineReminders(this.db, {NotificationService? notifications})
      : notifications = notifications ?? NotificationService();

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  /// Stable notification base id for a UUID-like string id.
  static int baseIdFor(String id) => id.hashCode & 0x3fffffff;

  /// Deadlines due after [now], soonest first.
  Future<List<ReminderDeadline>> upcoming(
    String userId, {
    String? groupId,
    DateTime? now,
  }) async {
    final nowMs = BigInt.from((now ?? DateTime.now()).millisecondsSinceEpoch);
    final tasks = await (db.select(db.tasks)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.status.equals('completed').not() &
              t.dueDate.isBiggerThanValue(nowMs) &
              (groupId == null
                  ? t.userId.equals(userId)
                  : (t.userId.equals(userId) |
                      (t.isGroup.equals(true) & t.groupId.equals(groupId))))))
        .get();
    final events = await (db.select(db.lmsEvents)
          ..where((e) =>
              e.userId.equals(userId) &
              e.isDeleted.equals(false) &
              e.isDone.equals(false) &
              e.eventType.equals('deadline') &
              e.startsAt.isBiggerThanValue(nowMs)))
        .get();

    final result = <ReminderDeadline>[
      for (final t in tasks)
        (
          id: t.id,
          title: t.title,
          dueDate: DateTime.fromMillisecondsSinceEpoch(t.dueDate!.toInt()),
        ),
      for (final e in events)
        (
          id: e.id,
          title: e.title,
          dueDate: DateTime.fromMillisecondsSinceEpoch(e.startsAt.toInt()),
        ),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  /// Persists the switch and schedules or cancels reminders.
  /// Returns the number of deadlines reminders were scheduled for.
  Future<int> setEnabled(
    bool enabled,
    String userId, {
    String? groupId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
    final deadlines = await upcoming(userId, groupId: groupId);
    for (final d in deadlines) {
      final baseId = baseIdFor(d.id);
      if (enabled) {
        await notifications.scheduleDeadlineReminders(
          baseId: baseId,
          taskTitle: d.title,
          dueDate: d.dueDate,
        );
      } else {
        await notifications.cancelTaskReminders(baseId);
      }
    }
    return enabled ? deadlines.length : 0;
  }
}
