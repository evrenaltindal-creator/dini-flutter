import 'package:flutter_test/flutter_test.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/qibla/domain/qibla_calculator.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';

void main() {
  const calc = LocalPrayerTimesCalculator();
  final locations = <String, Coordinates>{
    'Istanbul': const Coordinates(41.0082, 28.9784),
    'Mecca': const Coordinates(21.4225, 39.8262),
    'London': const Coordinates(51.5072, -0.1276),
    'New York': const Coordinates(40.7128, -74.0060),
  };
  test('prayer times are ordered for known locations', () {
    for (final c in locations.values) {
      final t = calc.calculate(DateTime(2026, 8, 26), c);
      final values = Prayer.values.map((p) => t.times[p]!).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i].isAfter(values[i - 1]), isTrue);
      }
    }
  });
  test('after Isha points to tomorrow Fajr', () {
    final t = calc.calculate(DateTime(2026, 8, 26), locations['Istanbul']!);
    final state = nextPrayerState(
      TimezoneService.local('Europe/Istanbul', 2026, 8, 26, 23),
      t,
    );
    expect(state.current, Prayer.isha);
    expect(state.next, Prayer.fajr);
    expect(state.nextTime.day, 27);
  });
  test('qibla bearings are locally calculated and Mecca is zero distance', () {
    const q = QiblaCalculator();
    expect(q.bearing(locations['Istanbul']!), closeTo(152, 5));
    expect(q.bearing(locations['London']!), closeTo(118, 5));
    expect(q.bearing(locations['New York']!), closeTo(58, 5));
    expect(q.bearing(QiblaCalculator.kaaba), closeTo(0, 0.01));
  });
}
