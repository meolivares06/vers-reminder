import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';

class NotificationService {
  static const _channelId = 'vers_reminder_status';
  static const _channelName = 'Rotation Status';
  static const _channelDesc =
      'Shows when wallpaper rotation is active in the background';
  static const _notificationId = 1;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidSettings),
      );
    } catch (_) {
      // Plugin init failure is non-fatal — notifications simply won't appear
      // but the app continues to work normally.
    }

    // Listen for notification requests via the event bus
    EventBus.instance.on<NotificationRequested>((event) async {
      if (event.title.isEmpty && event.body.isEmpty) {
        await cancel();
      } else {
        await show(event.body.isNotEmpty ? event.body : event.title);
      }
    });
  }

  static Future<void> show(String body) async {
    try {
      await _plugin.show(
        _notificationId,
        'Vers Reminder',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            showWhen: false,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (_) {
      // Silently ignore: platform not initialized (tests) or notification
      // channel unavailable. The notification is best-effort — failures
      // must never crash the app or break the wallpaper generation flow.
    }
  }

  static Future<void> cancel() async {
    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {
      // Silently ignore (same rationale as show).
    }
  }
}
