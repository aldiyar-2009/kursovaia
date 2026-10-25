import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification texts in the app language (no BuildContext here).
Future<AppLocalizations> _strings() async =>
    lookupAppLocalizations(await currentAppLocale());

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
    final strings = await _strings();
    final linuxSettings =
        LinuxInitializationSettings(defaultActionName: strings.notify_openAction);

    final initSettings = InitializationSettings(
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
    final strings = await _strings();

    // 24 hours before
    final reminder24h = dueDate.subtract(const Duration(hours: 24));
    if (reminder24h.isAfter(now)) {
      await _scheduleSingleNotification(
        strings,
        id: baseId * 2,
        title: strings.notify_deadline24hTitle,
        body: taskTitle,
        scheduledTime: reminder24h,
      );
    }

    // 2 hours before
    final reminder2h = dueDate.subtract(const Duration(hours: 2));
    if (reminder2h.isAfter(now)) {
      await _scheduleSingleNotification(
        strings,
        id: baseId * 2 + 1,
        title: strings.notify_deadline2hTitle,
        body: taskTitle,
        scheduledTime: reminder2h,
      );
    }
  }

  Future<void> _scheduleSingleNotification(
    AppLocalizations strings, {
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final androidDetails = AndroidNotificationDetails(
        'deadlines_channel',
        strings.notify_channelName,
        channelDescription: strings.notify_channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      final notificationDetails = NotificationDetails(android: androidDetails);

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
