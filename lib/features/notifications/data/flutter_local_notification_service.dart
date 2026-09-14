import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_system.dart';

class FlutterLocalNotificationService implements LocalNotificationService {
  final FlutterLocalNotificationsPlugin plugin;
  FlutterLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Eklentinin bu platformda kayıtlı olup olmadığı. [initialize] başarıyla
  /// tamamlanana kadar false kalır; eklentisiz ortamlarda (widget testleri,
  /// desteklenmeyen platformlar) bütün çağrılar sessizce atlanır, böylece
  /// planlama hatası arayüze sızmaz. Tercihler yerel olarak saklanmaya devam
  /// eder; yalnızca işletim sistemine bildirim kurulmaz.
  bool _available = false;

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    try {
      await plugin.initialize(settings);
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_available) return NotificationPermissionStatus.unknown;
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
  Future<void> cancelAll() async {
    if (!_available) return;
    await plugin.cancelAll();
  }

  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async {
    if (!_available) return;
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
