import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../../widgets/domain/widget_snapshot.dart';
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

  // Widget tazeleme kozmetiktir ve native köprüye bağlıdır; beklenmez.
  unawaited(const WidgetSnapshotService().refresh());
}
