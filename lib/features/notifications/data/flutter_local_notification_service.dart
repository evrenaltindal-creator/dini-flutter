import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_system.dart';
import 'notification_sound_installer.dart';

class FlutterLocalNotificationService implements LocalNotificationService {
  /// Sesi seçimden bağımsız olan eski kanal. Artık kurulmuyor, yalnızca
  /// yükseltilen cihazlardan temizleniyor.
  static const _retiredChannelId = 'dini_prayers';

  final FlutterLocalNotificationsPlugin plugin;

  /// Bildirim sesini iOS kabına kuran yardımcı. Testlerde değiştirilir.
  final NotificationSoundInstaller soundInstaller;

  FlutterLocalNotificationService([
    FlutterLocalNotificationsPlugin? plugin,
    NotificationSoundInstaller? soundInstaller,
  ]) : plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       soundInstaller = soundInstaller ?? const NotificationSoundInstaller();

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
      // Sesin kurulması bildirimlerin çalışmasının önkoşulu değildir; hata
      // durumunda sistem sesi kullanılır.
      await soundInstaller.install();
      // Sesi değiştirilemeyen eski tek kanaldan yükseltilen cihazlarda o kanal
      // ayarlarda öylece durur. Kimliği artık kullanılmıyor, silinir.
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(_retiredChannelId);
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

  /// Seçilen sese karşılık gelen Android bildirim kanalı.
  ///
  /// Her ses AYRI bir kanal kimliği alır. Android 8'den beri bir kanalın sesi
  /// oluşturulduktan sonra uygulama tarafından değiştirilemez; tek bir kanal
  /// kullanılsaydı kullanıcı ayarlardan sesi değiştirdiğinde hiçbir şey
  /// olmazdı, çünkü kanal ilk kurulduğu sesle kalırdı.
  static AndroidNotificationChannel androidChannelFor(
    NotificationSound sound,
  ) => switch (sound) {
    NotificationSound.defaultSound => const AndroidNotificationChannel(
      'dini_prayers_default',
      'Namaz vakitleri',
      description: 'Cihaz üzerinde hesaplanan namaz bildirimleri',
      importance: Importance.high,
    ),
    NotificationSound.bundled => const AndroidNotificationChannel(
      'dini_prayers_tone',
      'Namaz vakitleri (uygulama tonu)',
      description: 'Cihaz üzerinde hesaplanan namaz bildirimleri',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound(
        NotificationSoundInstaller.androidResourceName,
      ),
    ),
    NotificationSound.silent => const AndroidNotificationChannel(
      'dini_prayers_silent',
      'Namaz vakitleri (sessiz)',
      description: 'Cihaz üzerinde hesaplanan namaz bildirimleri',
      importance: Importance.high,
      playSound: false,
    ),
  };

  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async {
    if (!_available) return;
    final channel = androidChannelFor(sound);
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
        playSound: channel.playSound,
        sound: channel.sound,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound != NotificationSound.silent,
        sound: sound == NotificationSound.bundled
            ? NotificationSoundInstaller.soundFileName
            : null,
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
