import 'dart:convert';

import '../../../core/storage/local_storage.dart';
import '../domain/prayer_settings.dart';
import '../domain/timezone_service.dart';
import '../../../shared/models/domain.dart';

class PrayerSettingsRepository {
  static const key = 'dini.prayer_settings.v2';
  final LocalStorage storage;
  const PrayerSettingsRepository(this.storage);
  Future<void> save(PrayerSettings s) async {
    await storage.write(
      key,
      jsonEncode({
        'method': s.method.name,
        'asr': s.asrMethod.name,
        'use24': s.use24Hour,
        'mode': s.locationMode.name,
        'city': s.location.city,
        'lat': s.location.latitude,
        'lon': s.location.longitude,
        'tz': s.location.timezoneId,
        'hijriOffset': s.hijriOffset,
        'adjustments': {
          'fajr': s.adjustments.fajr,
          'dhuhr': s.adjustments.dhuhr,
          'asr': s.adjustments.asr,
          'maghrib': s.adjustments.maghrib,
          'isha': s.adjustments.isha,
        },
      }),
    );
  }

  Future<PrayerSettings> load() async {
    final raw = await storage.read(key);
    if (raw == null) return const PrayerSettings();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final lat = (m['lat'] as num?)?.toDouble();
      final lon = (m['lon'] as num?)?.toDouble();
      final tz = m['tz'] as String?;
      final location = LocationPreference(
        city: m['city'] as String?,
        latitude: lat,
        longitude: lon,
        timezoneId: TimezoneService.isValid(tz ?? '') ? tz : 'Europe/Istanbul',
      );
      final a = (m['adjustments'] as Map?)?.cast<String, dynamic>() ?? {};
      return PrayerSettings(
        method: PrayerCalculationMethod.values.byName(m['method'] as String),
        asrMethod: AsrMethod.values.byName(m['asr'] as String),
        use24Hour: (m['use24'] as bool?) ?? true,
        location: location,
        locationMode: LocationMode.values.byName(m['mode'] as String),
        // Beklenmeyen bir değer takvimi saatlerce kaydırmamalı.
        hijriOffset: ((m['hijriOffset'] as int?) ?? 0).clamp(-1, 1),
        adjustments: PrayerAdjustments(
          fajr: a['fajr'] as int? ?? 0,
          dhuhr: a['dhuhr'] as int? ?? 0,
          asr: a['asr'] as int? ?? 0,
          maghrib: a['maghrib'] as int? ?? 0,
          isha: a['isha'] as int? ?? 0,
        ),
      );
    } catch (_) {
      return const PrayerSettings();
    }
  }
}
