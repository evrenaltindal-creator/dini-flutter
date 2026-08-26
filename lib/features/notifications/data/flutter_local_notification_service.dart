import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_system.dart';

class FlutterLocalNotificationService implements LocalNotificationService {
  final FlutterLocalNotificationsPlugin plugin;
  FlutterLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings);
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final androidGranted = await android?.requestNotificationsPermission();
    if (iosGranted == true || androidGranted == true) {
      return NotificationPermissionStatus.granted;
    }
    if (iosGranted == false || androidGranted == false) {
      return NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.unknown;
  }

  @override
  Future<void> cancelAll() => plugin.cancelAll();
  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async {
    final channel = AndroidNotificationChannel(
      'dini_prayers',
      'Namaz vakitleri',
      description: 'Cihaz üzerinde hesaplanan namaz bildirimleri',
      importance: Importance.high,
      playSound: sound != NotificationSound.silent,
      sound: sound == NotificationSound.bundled
          ? const RawResourceAndroidNotificationSound('adhan')
          : null,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound != NotificationSound.silent,
        sound: sound == NotificationSound.bundled
            ? const RawResourceAndroidNotificationSound('adhan')
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound != NotificationSound.silent,
        sound: sound == NotificationSound.bundled ? 'adhan.aiff' : null,
      ),
    );
    await plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      tz.TZDateTime.from(notification.scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
