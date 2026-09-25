import 'package:flutter/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/domain.dart';
import '../../home/domain/mosque_scene_state.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../domain/widget_snapshot.dart';
import 'widget_preferences_repository.dart';

/// Ayarlardan ana ekran widget'ının anlık görüntüsünü çıkarır.
///
/// Vakitler kullanıcının seçtiği yerin gününe göre hesaplanır; uygulamanın
/// geri kalanı da öyle yapar.
WidgetSnapshot buildWidgetSnapshot({
  required PrayerSettings settings,
  required DateTime now,
  required String languageCode,
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) {
  final location = settings.location;
  final timezoneId = location.timezoneId ?? 'Europe/Istanbul';
  final localNow = TimezoneService.inLocation(timezoneId, now);
  final times = calculator.calculate(
    localNow,
    Coordinates(location.latitude ?? 41.0082, location.longitude ?? 28.9784),
    method: settings.method,
    asrMethod: settings.asrMethod,
    adjustments: settings.adjustments,
    timezoneId: timezoneId,
  );
  final next = nextPrayerState(localNow, times);
  final l10n = AppLocalizations(Locale(languageCode));
  final scene = const MosqueSceneStateResolver().resolve(localNow, times);
  // Yatsıdan sonra sıradaki vakit yarının sabahıdır: gerçek vakti o günün
  // hesabından alınır (bugünün sabah saatini ertesi güne kaydırmak birkaç
  // dakika şaşar).
  final tomorrow = calculator.calculate(
    localNow.add(const Duration(days: 1)),
    Coordinates(location.latitude ?? 41.0082, location.longitude ?? 28.9784),
    method: settings.method,
    asrMethod: settings.asrMethod,
    adjustments: settings.adjustments,
    timezoneId: timezoneId,
  );

  return WidgetSnapshot(
    effectiveDate: times.date,
    locationName: location.city,
    prayers: times.times,
    nextPrayer: next.next,
    nextPrayerTime: next.nextTime,
    scenePeriod: scene.period,
    labels: {
      for (final prayer in Prayer.values) prayer: l10n.prayer(prayer.name),
    },
    tomorrowFajr: tomorrow.times[Prayer.fajr],
    extraLabels: {
      'remaining': l10n.text('widget.remaining'),
      'tasbih': l10n.text('home.tasbih'),
      'qibla': l10n.text('home.qibla'),
      'tracker': l10n.text('worship.tracker'),
    },
  );
}

/// Anlık görüntüyü hesaplayıp native tarafa yazar.
///
/// **Bu yol yazılana kadar widget hiçbir veri almıyordu:** uygulama yalnızca
/// `refresh()` çağırıyor, yani uzantıya "zaman çizelgeni yenile" diyordu ama
/// okuyacağı değerleri kimse yazmamıştı. Widget de hep yer tutucu metinleri
/// gösteriyordu.
Future<void> pushWidgetSnapshot({
  required LocalStorage storage,
  required PrayerSettings settings,
  required DateTime now,
  WidgetSnapshotService service = const WidgetSnapshotService(),
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) async {
  final languageCode = await storage.read(localePreferenceKey) ?? 'tr';
  final showLocationName = await WidgetPreferencesRepository(storage)
      .showLocationName();

  await service.update(
    buildWidgetSnapshot(
      settings: settings,
      now: now,
      languageCode: languageCode,
      calculator: calculator,
    ),
    showLocationName: showLocationName,
  );
  await service.refresh();
}
