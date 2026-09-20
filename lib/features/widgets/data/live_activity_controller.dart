import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/domain.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../domain/live_activity.dart';

/// Canlı etkinliği olması gereken duruma getirir.
///
/// Süren etkinliğin aynası cihazda saklanır: etkinlik uygulamadan uzun
/// yaşar, uygulama yeniden açıldığında neyin açık olduğunu bilmeden ikinci
/// bir etkinlik başlatılırsa kilit ekranında iki sayaç birden görünür.
class LiveActivityController {
  static const stateKey = 'dini.liveActivity.current';

  final LocalStorage storage;
  final LiveActivityService service;

  const LiveActivityController({
    required this.storage,
    this.service = const LiveActivityService(),
  });

  Future<LiveActivityAction> sync({
    required DateTime now,
    required LiveActivityState? desired,
  }) async {
    final running = _decode(await storage.read(stateKey));
    final action = liveActivityAction(
      now: now,
      desired: desired,
      running: running,
    );
    switch (action) {
      case LiveActivityAction.start:
        await service.start(desired!);
        await storage.write(stateKey, jsonEncode(desired.toJson()));
      case LiveActivityAction.update:
        await service.update(desired!);
        await storage.write(stateKey, jsonEncode(desired.toJson()));
      case LiveActivityAction.end:
        await service.end();
        await storage.remove(stateKey);
      case LiveActivityAction.none:
        break;
    }
    return action;
  }

  LiveActivityState? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final prayer = Prayer.values
          .where((item) => item.name == map['prayer'])
          .firstOrNull;
      final time = DateTime.tryParse(map['prayerTime'] as String? ?? '');
      if (prayer == null || time == null) return null;
      return LiveActivityState(
        prayer: prayer,
        prayerTime: time,
        prayerLabel: map['prayerLabel'] as String? ?? prayer.name,
        locationName: map['locationName'] as String?,
      );
    } on FormatException {
      // Bozuk ayna, etkinliğin hiç açılmadığı anlamına gelir.
      return null;
    }
  }
}

/// Ayarlardan sıradaki vakti çıkarıp canlı etkinliği günceller.
///
/// Metinler burada, uygulamanın dilinde hazırlanır: uzantının çeviri
/// haritasına erişimi yok.
Future<LiveActivityAction> syncLiveActivity({
  required LocalStorage storage,
  required PrayerSettings settings,
  required DateTime now,
  LiveActivityService service = const LiveActivityService(),
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) async {
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

  final languageCode = await storage.read(localePreferenceKey) ?? 'tr';
  final l10n = AppLocalizations(Locale(languageCode));
  final prayer = next.next;
  final desired = prayer == null
      ? null
      : LiveActivityState(
          prayer: prayer,
          prayerTime: next.nextTime,
          prayerLabel: l10n.prayer(prayer.name),
          locationName: location.city,
        );

  return LiveActivityController(
    storage: storage,
    service: service,
  ).sync(now: localNow, desired: desired);
}
