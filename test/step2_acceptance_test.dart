import 'package:flutter_test/flutter_test.dart';
import 'package:dini_flutter/features/prayer_times/data/location_service.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/qibla/domain/qibla_calculator.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';

void main() {
  const calc = LocalPrayerTimesCalculator();
  const qibla = QiblaCalculator();
  final locations = <String, Coordinates>{
    'Istanbul': const Coordinates(41.0082, 28.9784),
    'Mecca': const Coordinates(21.4225, 39.8262),
    'London': const Coordinates(51.5072, -0.1276),
    'New York': const Coordinates(40.7128, -74.0060),
  };
  final date = DateTime(2026, 8, 26);

  for (final method in PrayerCalculationMethod.values.take(3)) {
    test('prayer ordering for all locations with $method', () {
      for (final point in locations.values) {
        final t = calc.calculate(date, point, method: method);
        final v = Prayer.values.map((p) => t.times[p]!).toList();
        expect(v[0].isBefore(v[1]), isTrue);
        expect(v[1].isBefore(v[2]), isTrue);
        expect(v[2].isBefore(v[3]), isTrue);
        expect(v[3].isBefore(v[4]), isTrue);
        expect(v[4].isBefore(v[5]), isTrue);
      }
    });
  }
  test('boundary semantics are consistent: exact time advances to following prayer', () {
    final t = calc.calculate(date, locations['Istanbul']!);
    final fajr = t.times[Prayer.fajr]!;
    expect(nextPrayerState(fajr, t).next, Prayer.sunrise);
    expect(nextPrayerState(t.times[Prayer.dhuhr]!, t).next, Prayer.asr);
    expect(nextPrayerState(t.times[Prayer.isha]!, t).next, Prayer.fajr);
  });
  test('all next prayer intervals are deterministic', () {
    final t = calc.calculate(date, locations['Istanbul']!);
    for (final p in Prayer.values) {
      final at = t.times[p]!.subtract(const Duration(minutes: 1));
      expect(nextPrayerState(at, t).next, p);
    }
  });
  test('after Isha recalculates tomorrow Fajr date', () {
    final today = calc.calculate(date, locations['Istanbul']!);
    final state = nextPrayerState(
      TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 23, 59),
      today,
    );
    expect(state.next, Prayer.fajr);
    expect(state.nextTime.year, 2026);
    expect(state.nextTime.month, 8);
    expect(state.nextTime.day, 27);
    expect(state.nextTime.hour, 4);
    expect(state.nextTime.minute, 48);
  });
  test('near midnight and next calendar day remain positive', () {
    final t = calc.calculate(date, locations['Istanbul']!);
    final state = nextPrayerState(
      TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 23, 59, 59),
      t,
    );
    expect(state.remaining > Duration.zero, isTrue);
  });
  test('qibla bearings are normalized for city and Mecca points', () {
    for (final point in [
      locations['Istanbul']!,
      locations['London']!,
      locations['New York']!,
      locations['Mecca']!,
    ]) {
      final value = qibla.bearing(point);
      expect(value >= 0 && value < 360, isTrue);
    }
    expect(qibla.bearing(locations['Istanbul']!), closeTo(152, 5));
    expect(qibla.bearing(locations['London']!), closeTo(119, 5));
    expect(qibla.bearing(locations['New York']!), closeTo(58, 5));
    expect(qibla.bearing(QiblaCalculator.kaaba), closeTo(0, 0.01));
  });
  test('manual coordinates validate geographic bounds', () {
    expect(DeviceLocationService.valid(const Coordinates(90, 180)), isTrue);
    expect(DeviceLocationService.valid(const Coordinates(-90, -180)), isTrue);
    expect(DeviceLocationService.valid(const Coordinates(90.1, 0)), isFalse);
    expect(DeviceLocationService.valid(const Coordinates(0, 180.1)), isFalse);
  });
  test(
    'minute adjustments change displayed times without changing domain date',
    () {
      final t = calc.calculate(
        date,
        locations['Istanbul']!,
        adjustments: const PrayerAdjustments(
          fajr: 2,
          dhuhr: -1,
          asr: 3,
          maghrib: 0,
          isha: -2,
        ),
      );
      expect(t.times[Prayer.fajr]!.hour, 4);
      expect(t.times[Prayer.fajr]!.minute, 50);
      expect(t.times[Prayer.dhuhr]!.hour, 11);
      expect(t.times[Prayer.dhuhr]!.minute, 59);
      expect(t.times[Prayer.asr]!.hour, 16);
      expect(t.times[Prayer.asr]!.minute, 33);
      expect(t.times[Prayer.isha]!.hour, 19);
      expect(t.times[Prayer.isha]!.minute, 13);
    },
  );
  test('12 and 24 hour formatting are display-only', () {
    final value = DateTime(2026, 8, 26, 19, 42);
    expect(formatPrayerTime(value), '19:42');
    expect(formatPrayerTime(value, use24Hour: false), '7:42 PM');
  });
  test('calculation is independent from device timezone identifiers', () {
    final london = calc.calculate(DateTime(2026, 3, 29), locations['London']!);
    final newYork = calc.calculate(
      DateTime(2026, 11, 1),
      locations['New York']!,
    );
    expect(london.date, DateTime(2026, 3, 29));
    expect(newYork.date, DateTime(2026, 11, 1));
  });
}
