import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/qibla/domain/qibla_calculator.dart';
import 'package:dini_flutter/features/worship/domain/worship_guide.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide covers the five daily prayers in order', () {
    expect(dailyPrayerGuides.map((guide) => guide.prayer), [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]);
    expect(dailyPrayerGuides.map((guide) => guide.totalRakats), [
      4,
      10,
      8,
      5,
      13,
    ]);
  });

  test('fard appears once and prayer components have positive rakats', () {
    for (final guide in dailyPrayerGuides) {
      expect(
        guide.parts.where((part) => part.kind == PrayerPartKind.fard),
        hasLength(1),
      );
      expect(guide.parts.every((part) => part.rakats > 0), isTrue);
    }
  });

  test('alarm preferences cover the same five prayers', () {
    expect(notificationPrayers, [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]);
  });

  test('qibla turn direction takes the shortest path across north', () {
    const calculator = QiblaCalculator();
    expect(
      calculator.turnDifference(bearing: 10, heading: 350),
      closeTo(20, .001),
    );
    expect(
      calculator.turnDifference(bearing: 350, heading: 10),
      closeTo(-20, .001),
    );
  });
}
