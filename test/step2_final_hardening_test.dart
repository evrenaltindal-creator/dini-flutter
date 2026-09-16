import 'package:flutter_test/flutter_test.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/prayer_times/data/prayer_settings_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_clock.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';

class MemoryStorage implements LocalStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}

void main() {
  test('IANA timezone rules distinguish London DST dates', () {
    final before = TimezoneService.local('Europe/London', 2026, 3, 28, 12);
    final after = TimezoneService.local('Europe/London', 2026, 3, 30, 12);
    expect(before.timeZoneOffset, const Duration(hours: 0));
    expect(after.timeZoneOffset, const Duration(hours: 1));
  });
  test('IANA timezone rules distinguish New York DST dates', () {
    final winter = TimezoneService.local('America/New_York', 2026, 1, 15, 12);
    final summer = TimezoneService.local('America/New_York', 2026, 7, 15, 12);
    expect(winter.timeZoneOffset, const Duration(hours: -5));
    expect(summer.timeZoneOffset, const Duration(hours: -4));
  });
  test('manual New York timezone is not replaced by host timezone', () {
    final t = const LocalPrayerTimesCalculator().calculate(
      DateTime(2026, 7, 15),
      const Coordinates(40.7128, -74.006),
      timezoneId: 'America/New_York',
    );
    expect(t.timezoneId, 'America/New_York');
    expect(t.times[Prayer.dhuhr]!.timeZoneOffset, const Duration(hours: -4));
  });
  test(
    'invalid timezone is controlled and repository falls back safely',
    () async {
      expect(TimezoneService.isValid('Mars/Phobos'), isFalse);
      final storage = MemoryStorage()
        ..data[PrayerSettingsRepository.key] =
            '{"method":"bad","tz":"Mars/Phobos"}';
      final loaded = await PrayerSettingsRepository(storage).load();
      expect(loaded.method, PrayerCalculationMethod.diyanet);
      expect(loaded.location.timezoneId, 'Europe/Istanbul');
    },
  );
  test('rollover recalculates timetable once and resume same day does not', () {
    final clock = FakeClock(
      TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 23, 55),
    );
    final controller = PrayerDayController(
      calculator: const LocalPrayerTimesCalculator(),
      coordinates: const Coordinates(41, 29),
      settings: const PrayerSettings(),
      clock: clock,
    );
    controller.times;
    expect(controller.calculationCount, 1);
    clock.set(TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 23, 59));
    controller.onResume();
    controller.times;
    expect(controller.calculationCount, 1);
    clock.set(TimezoneService.local('Europe/Istanbul', 2026, 8, 27, 0, 5));
    controller.onResume();
    controller.times;
    expect(controller.calculationCount, 2);
  });
  test('resume refreshes next prayer without requesting location again', () {
    final clock = FakeClock(
      TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 14),
    );
    final controller = PrayerDayController(
      calculator: const LocalPrayerTimesCalculator(),
      coordinates: const Coordinates(41, 29),
      settings: const PrayerSettings(),
      clock: clock,
    );
    final first = controller.state;
    clock.set(TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 14, 20));
    controller.onResume();
    final resumed = controller.state;
    expect(resumed.next, first.next);
    expect(resumed.remaining < first.remaining, isTrue);
    expect(controller.calculationCount, 1);
  });
  test('settings persist and recreate through storage abstraction', () async {
    final storage = MemoryStorage();
    final repo = PrayerSettingsRepository(storage);
    const settings = PrayerSettings(
      method: PrayerCalculationMethod.isna,
      asrMethod: AsrMethod.standard,
      use24Hour: false,
      location: LocationPreference(
        city: 'New York',
        latitude: 40.7128,
        longitude: -74.006,
        timezoneId: 'America/New_York',
      ),
      adjustments: PrayerAdjustments(fajr: 2, dhuhr: -1, asr: 3, isha: -2),
    );
    await repo.save(settings);
    final restored = await PrayerSettingsRepository(storage).load();
    expect(restored.method, PrayerCalculationMethod.isna);
    expect(restored.asrMethod, AsrMethod.standard);
    expect(restored.use24Hour, isFalse);
    expect(restored.location.city, 'New York');
    expect(restored.location.timezoneId, 'America/New_York');
    expect(restored.adjustments.asr, 3);
  });
  test('fresh storage returns safe defaults', () async {
    final restored = await PrayerSettingsRepository(MemoryStorage()).load();
    expect(restored.method, PrayerCalculationMethod.diyanet);
    // Diyanet ikindiyi asr-ı evvel ile yayımlar; varsayılan onunla örtüşür.
    // Hanefî seçeneği Ayarlar'dan seçilebilir durumda kalır.
    expect(restored.asrMethod, AsrMethod.standard);
    expect(restored.location.timezoneId, 'Europe/Istanbul');
  });
}
