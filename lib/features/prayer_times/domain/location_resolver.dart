import '../../../shared/models/domain.dart';
import '../data/location_service.dart';
import 'city.dart';
import 'timezone_service.dart';

/// Konum çözümünün sonucu.
enum LocationOutcome {
  /// Konum bulundu ve kaydedilebilir.
  resolved,

  /// Kullanıcı izin vermedi ya da kalıcı olarak reddetti.
  permissionDenied,

  /// Konum servisi kapalı, ölçüm başarısız ya da koordinat geçersiz.
  unavailable,
}

class LocationResult {
  final LocationOutcome outcome;
  final LocationPreference? preference;

  const LocationResult(this.outcome, [this.preference]);

  bool get isResolved => outcome == LocationOutcome.resolved;
}

/// Cihaz konumunu kullanıcının kaydedebileceği bir tercihe çevirir.
///
/// İki işi birleştirir:
///
/// 1. GPS'ten koordinat almak.
/// 2. O koordinatın **saat dilimini** bulmak.
///
/// İkincisi olmadan birincisinin bir anlamı yok: Berlin'in koordinatlarını
/// İstanbul saat dilimiyle hesaplamak vakitleri bir saat kaydırır. Saat dilimi
/// haritası paketlemek yerine paketlenmiş şehir listesindeki en yakın şehrin
/// dilimi alınır — uygulama çevrimdışıdır, geocoding servisi çağrılamaz.
class LocationResolver {
  final LocationService service;
  final CityDirectory directory;

  const LocationResolver({required this.service, required this.directory});

  /// Cihazın konumunu ölçer ve kaydedilebilir bir tercihe çevirir.
  Future<LocationResult> resolveAutomatic() async {
    final DeviceLocation? reading;
    try {
      reading = await service.automatic();
    } catch (_) {
      // Eklenti hatası uygulamayı düşürmemeli; kullanıcı şehri elle seçebilir.
      return const LocationResult(LocationOutcome.unavailable);
    }
    if (reading == null) {
      return const LocationResult(LocationOutcome.permissionDenied);
    }
    if (!DeviceLocationService.valid(reading.coordinates)) {
      return const LocationResult(LocationOutcome.unavailable);
    }

    final nearest = directory.nearest(reading.coordinates);
    return LocationResult(
      LocationOutcome.resolved,
      LocationPreference(
        // Konumun adı en yakın şehirden gelir; "Cihaz konumu" yazmaktansa
        // kullanıcıya nerede olduğunu söylemek daha yararlı.
        city: nearest?.name,
        latitude: reading.coordinates.latitude,
        longitude: reading.coordinates.longitude,
        timezoneId: _timezoneFor(nearest),
      ),
    );
  }

  /// Listeden seçilen bir şehri tercihe çevirir.
  static LocationPreference fromCity(City city) => LocationPreference(
    city: city.name,
    latitude: city.latitude,
    longitude: city.longitude,
    timezoneId: _timezoneFor(city),
  );

  /// Şehrin saat dilimi. Tanınmayan bir kimlik uygulamayı düşürmemeli;
  /// böyle bir durumda varsayılan dilime düşülür ve vakitler yine hesaplanır.
  static String _timezoneFor(City? city) {
    final id = city?.timezoneId;
    if (id != null && TimezoneService.isValid(id)) return id;
    return 'Europe/Istanbul';
  }
}
