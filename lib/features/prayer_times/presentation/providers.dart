import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final asrMethodProvider = StateProvider<AsrMethod>((ref) => AsrMethod.hanafi);
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
