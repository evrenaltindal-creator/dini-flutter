import 'prayer_engine.dart';
import 'prayer_settings.dart';
import '../../../shared/models/domain.dart';

abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  DateTime value;
  FakeClock(this.value);
  @override
  DateTime now() => value;
  void set(DateTime next) => value = next;
}

class PrayerDayController {
  final PrayerTimesCalculator calculator;
  final Coordinates coordinates;
  final PrayerSettings settings;
  final Clock clock;
  PrayerTimes? _times;
  DateTime? _effectiveDate;
  int calculationCount = 0;
  PrayerDayController({
    required this.calculator,
    required this.coordinates,
    required this.settings,
    required this.clock,
  });
  PrayerTimes get times {
    final current = clock.now();
    final date = DateTime(current.year, current.month, current.day);
    if (_times == null || _effectiveDate != date) {
      _times = calculator.calculate(
        current,
        coordinates,
        method: settings.method,
        asrMethod: settings.asrMethod,
        adjustments: settings.adjustments,
        timezoneId: settings.location.timezoneId ?? 'Europe/Istanbul',
      );
      _effectiveDate = date;
      calculationCount++;
    }
    return _times!;
  }

  NextPrayerState get state => nextPrayerState(clock.now(), times);
  void onResume() {
    final current = clock.now();
    final date = DateTime(current.year, current.month, current.day);
    if (_effectiveDate != date) {
      _times = null;
    }
  }
}
