import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/city_repository.dart';
import '../data/location_service.dart';
import '../domain/city.dart';
import '../domain/location_resolver.dart';
import '../domain/monthly_timetable.dart';
import '../domain/prayer_engine.dart';
import '../domain/prayer_settings.dart';
import 'settings_controller.dart';
import '../../../shared/models/domain.dart';

final coordinatesProvider = StateProvider<Coordinates>(
  (ref) => const Coordinates(41.0082, 28.9784),
);
final calculationMethodProvider = StateProvider<PrayerCalculationMethod>(
  (ref) => PrayerCalculationMethod.diyanet,
);
// Diyanet'in yayımladığı vakitlerle uyum için standart hesap; bkz.
// PrayerSettings.asrMethod.
final asrMethodProvider = StateProvider<AsrMethod>((ref) => AsrMethod.standard);
final effectivePrayerSettingsProvider = Provider<PrayerSettings>(
  (ref) => ref
      .watch(prayerSettingsProvider)
      .maybeWhen(data: (value) => value, orElse: () => const PrayerSettings()),
);
final prayerTimesProvider = Provider<PrayerTimes>((ref) {
  final settings = ref.watch(effectivePrayerSettingsProvider);
  final location = settings.location;
  final coordinates = Coordinates(
    location.latitude ?? 41.0082,
    location.longitude ?? 28.9784,
  );
  return const LocalPrayerTimesCalculator().calculate(
    DateTime.now(),
    coordinates,
    method: settings.method,
    asrMethod: settings.asrMethod,
    adjustments: settings.adjustments,
    timezoneId: location.timezoneId ?? 'Europe/Istanbul',
  );
});
final nextPrayerProvider = Provider<NextPrayerState>(
  (ref) => nextPrayerState(DateTime.now(), ref.watch(prayerTimesProvider)),
);

/// Seçili konum ve hesap ayarlarıyla bir ayın imsakiyesi.
///
/// `family` anahtarı ayın ilk günüdür; aynı ay tekrar istendiğinde yeniden
/// hesaplanmaması için `Provider.family` önbelleğe alır.
final monthlyTimetableProvider = Provider.family<MonthlyTimetable, DateTime>((
  ref,
  month,
) {
  final settings = ref.watch(effectivePrayerSettingsProvider);
  final location = settings.location;
  return monthlyTimetable(
    month: month,
    coordinates: Coordinates(
      location.latitude ?? 41.0082,
      location.longitude ?? 28.9784,
    ),
    method: settings.method,
    asrMethod: settings.asrMethod,
    adjustments: settings.adjustments,
    timezoneId: location.timezoneId ?? 'Europe/Istanbul',
  );
});

/// Paketlenmiş şehir listesi. Tek bir kopya tutulur; varlık her aramada
/// yeniden çözülmemeli.
final cityRepositoryProvider = Provider((ref) => CityRepository());

final cityDirectoryProvider = FutureProvider<CityDirectory>(
  (ref) => ref.watch(cityRepositoryProvider).load(),
);

/// Cihaz konumunu okuyan servis. Testlerde sahte bir servisle değiştirilir.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const DeviceLocationService(),
);

/// Konumu ölçüp kaydedilebilir bir tercihe çeviren çözümleyici.
final locationResolverProvider = FutureProvider<LocationResolver>(
  (ref) async => LocationResolver(
    service: ref.watch(locationServiceProvider),
    directory: await ref.watch(cityDirectoryProvider.future),
  ),
);
