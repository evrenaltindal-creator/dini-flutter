import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Uygulamanın sistem ayarları sayfasını açar.
///
/// Pil optimizasyonu ve otomatik başlatma ayarları üretici arayüzlerinde
/// farklı yerlerde durur ve bu ekranların intent'leri belgelenmemiştir;
/// doğrudan açmaya çalışmak cihazdan cihaza kırılır. Uygulamanın kendi ayar
/// sayfası her Android sürümünde vardır ve pil ayarı oradan ulaşılabilir.
///
/// `geolocator` zaten bağımlıdır ve bu köprüyü sunar; yalnızca ayar sayfasını
/// açmak için yeni bir eklenti eklemeye gerek yok.
abstract class SystemSettings {
  /// Ayar sayfasını açar; açılabildiyse true.
  Future<bool> openAppSettings();
}

class DeviceSystemSettings implements SystemSettings {
  const DeviceSystemSettings();

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      // Ayar sayfası açılamazsa rehberdeki adımlar elle izlenebilir.
      return false;
    }
  }
}

/// Ayar sayfasını açan servis. Testlerde değiştirilir.
///
/// Hem ilk açılış akışı hem de bildirim ayarları ekranı pil rehberini
/// gösterir; sağlayıcı bu yüzden tek bir ekrana değil veri katmanına aittir.
final systemSettingsProvider = Provider<SystemSettings>(
  (ref) => const DeviceSystemSettings(),
);
