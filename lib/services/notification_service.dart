import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/document.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Wrapper around `flutter_local_notifications` for DocShelf's
/// expiry reminders.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  /// Tap handler — set from `MainShell` so notification taps can deep-link
  /// to the document viewer.
  void Function(int docId)? onNotificationTapped;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDesc,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _onTap(NotificationResponse r) {
    final payload = r.payload;
    if (payload == null) return;
    final id = int.tryParse(payload);
    if (id != null) onNotificationTapped?.call(id);
  }

  Future<void> scheduleExpiryReminder(Document doc) async {
    if (doc.id == null || doc.expiryDate == null) return;
    await cancelReminder(doc.id!);

    final fireAt =
        doc.expiryDate!.subtract(Duration(days: doc.reminderDays));
    final now = DateTime.now();
    final scheduled = fireAt.isBefore(now)
        ? now.add(const Duration(seconds: 5))
        : fireAt;

    final body = doc.isExpired
        ? '${doc.name} has expired.'
        : '${doc.name} expires in ${doc.reminderDays} days.';

    await _plugin.zonedSchedule(
      doc.id!,
      '📅 Expiring Soon',
      body,
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '${doc.id}',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int docId) => _plugin.cancel(docId);

  Future<void> cancelAllReminders() => _plugin.cancelAll();

  /// Re-registers reminders for every document with an expiry date. Call on
  /// app start (covers reinstalls + reboots).
  Future<void> rescheduleAllReminders() async {
    final docs = await DatabaseService.instance.getExpiringDocuments(365 * 30);
    for (final d in docs) {
      await scheduleExpiryReminder(d);
    }
  }

  Future<void> showTestNotification() async {
    await _plugin.show(
      99999,
      '🔔 Test reminder',
      'Notifications are working — you\'ll get expiry alerts here.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
