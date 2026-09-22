import 'package:flutter/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/local_storage.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../widgets/data/widget_preferences_repository.dart';
import '../domain/watch_schedule.dart';

/// Ayarlardan saate gidecek çizelgeyi çıkarır.
///
/// Günler seçilen şehrin takvimine göre sayılır: motor kendisine verilen
/// tarihin yıl/ay/gün alanlarını olduğu gibi kullanır, bu yüzden "bugün"
/// önce şehrin saat dilimine çevrilir (uygulamanın geri kalanı gibi).
WatchSchedule buildWatchSchedule({
  required PrayerSettings settings,
  required DateTime now,
  required String languageCode,
  required bool showLocationName,
  int days = watchScheduleDays,
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) {
  final location = settings.location;
  final timezoneId = location.timezoneId ?? 'Europe/Istanbul';
  final coordinates = Coordinates(
    location.latitude ?? 41.0082,
    location.longitude ?? 28.9784,
  );
  final today = TimezoneService.inLocation(timezoneId, now);
  final l10n = AppLocalizations(Locale(languageCode));

  return WatchSchedule(
    generatedAt: now,
    timezoneId: timezoneId,
    locationName: showLocationName ? location.city : null,
    labels: {
      for (final prayer in watchPrayers) prayer: l10n.prayer(prayer.name),
    },
    texts: {for (final key in watchTextKeys) key: l10n.text(key)},
    days: [
      for (var offset = 0; offset < days; offset++)
        _day(
          // Takvim günü aritmetiği: yaz saati geçişinde 24 saat eklemek
          // günü atlatabilirdi, gün alanını artırmak atlatmaz.
          DateTime(today.year, today.month, today.day + offset),
          coordinates: coordinates,
          settings: settings,
          timezoneId: timezoneId,
          calculator: calculator,
        ),
    ],
  );
}

WatchDay _day(
  DateTime date, {
  required Coordinates coordinates,
  required PrayerSettings settings,
  required String timezoneId,
  required PrayerTimesCalculator calculator,
}) {
  final times = calculator.calculate(
    date,
    coordinates,
    method: settings.method,
    asrMethod: settings.asrMethod,
    adjustments: settings.adjustments,
    timezoneId: timezoneId,
  );
  return WatchDay(date: date, times: times.times);
}

/// Çizelgeyi hesaplayıp saate gönderir.
///
/// Widget'la aynı anlarda çağrılır: açılışta, ayar kaydında ve konum adı
/// anahtarı değişince. Vakitleri etkileyen bir yol bunu çağırmazsa saat
/// eski şehrin vakitlerini göstermeye devam eder.
Future<void> pushWatchSchedule({
  required LocalStorage storage,
  required PrayerSettings settings,
  required DateTime now,
  WatchScheduleService service = const WatchScheduleService(),
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) async {
  final languageCode = await storage.read(localePreferenceKey) ?? 'tr';
  final showLocationName = await WidgetPreferencesRepository(storage)
      .showLocationName();
  await service.send(
    buildWatchSchedule(
      settings: settings,
      now: now,
      languageCode: languageCode,
      showLocationName: showLocationName,
      calculator: calculator,
    ),
  );
}
