import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../../widgets/data/live_activity_controller.dart';
import '../../widgets/data/widget_snapshot_builder.dart';
import '../../watch/data/watch_schedule_builder.dart';
import '../domain/prayer_settings.dart';
import 'settings_controller.dart';

/// Hesaplama ayarlarını kaydetmenin **tek** yolu.
///
/// Kaydetmek üç şeyi birlikte gerektirir: ayarı yazmak, bildirimleri yeniden
/// planlamak ve ana ekran widget'ını tazelemek. Bunlar ayrı ayrı çağrıldığında
/// biri unutulabiliyordu; konum değiştiğinde alarmların eski şehrin
/// vakitleriyle kalması bunun en pahalı hâli olurdu.
Future<void> savePrayerSettings(WidgetRef ref, PrayerSettings value) async {
  await ref.read(prayerSettingsProvider.notifier).saveSettings(value);

  // Alarmlar widget'tan ÖNCE kurulur. Ters sırada, native widget köprüsü
  // yanıt vermediğinde zincir orada durup bildirimleri hiç yeniden
  // planlamıyordu: kullanıcı şehrini değiştiriyor, ekranda yeni vakitleri
  // görüyor ama alarmlar eski şehrin saatleriyle çalmaya devam ediyordu.
  await reschedulePrayerNotifications(
    storage: ref.read(localStorageProvider),
    settings: value,
    // Servis provider'dan alınır; doğrudan yeni bir örnek kurmak bildirim
    // servisinin ikinci kez kurulmasına ve testlerde sahte servisin hiç
    // devreye girmemesine yol açardı.
    service: ref.read(notificationServiceProvider),
  );

  // Kilit ekranındaki canlı etkinlik de vakitlere bağlıdır; şehir değişince
  // eski şehrin sayacı kilit ekranında asılı kalırdı.
  unawaited(
    syncLiveActivity(
      storage: ref.read(localStorageProvider),
      settings: value,
      now: DateTime.now(),
    ),
  );

  // Widget'a VERİ yazılır, yalnızca "tazele" denmez: uzantı okuyacağı
  // değerleri uygulamadan alır ve bu yol yazılana kadar hiç yazılmıyordu.
  // Kozmetiktir ve native köprüye bağlıdır; beklenmez.
  unawaited(
    pushWidgetSnapshot(
      storage: ref.read(localStorageProvider),
      settings: value,
      now: DateTime.now(),
    ),
  );

  // Saat vakitleri kendisi hesaplamaz; şehir ya da yöntem değişince yeni
  // çizelge gönderilmezse eski vakitleri göstermeye devam eder.
  unawaited(
    pushWatchSchedule(
      storage: ref.read(localStorageProvider),
      settings: value,
      now: DateTime.now(),
    ),
  );
}
