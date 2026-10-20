import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(settings: initSettings);
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  Future<void> scheduleDeadlineReminders({
    required int baseId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    if (!_isInitialized) return;

    final now = DateTime.now();

    // 24 hours before
    final reminder24h = dueDate.subtract(const Duration(hours: 24));
    if (reminder24h.isAfter(now)) {
      await _scheduleSingleNotification(
        id: baseId * 2,
        title: 'Горит дедлайн: через 24 часа',
        body: taskTitle,
        scheduledTime: reminder24h,
      );
    }

    // 2 hours before
    final reminder2h = dueDate.subtract(const Duration(hours: 2));
    if (reminder2h.isAfter(now)) {
      await _scheduleSingleNotification(
        id: baseId * 2 + 1,
        title: 'Срочный дедлайн: через 2 часа!',
        body: taskTitle,
        scheduledTime: reminder2h,
      );
    }
  }

  Future<void> _scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'deadlines_channel',
        'Дедлайны и задачи',
        channelDescription: 'Уведомления о сроках сдачи заданий',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelTaskReminders(int baseId) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id: baseId * 2);
      await _notificationsPlugin.cancel(id: baseId * 2 + 1);
    } catch (_) {}
  }
}
