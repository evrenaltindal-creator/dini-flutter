import '../../../shared/models/domain.dart';
import 'prayer_settings.dart';
import 'timezone_service.dart';

class Coordinates {
  final double latitude, longitude;
  const Coordinates(this.latitude, this.longitude);
}

class NextPrayerState {
  final Prayer? current, next;
  final DateTime nextTime;
  final Duration remaining;
  const NextPrayerState({
    this.current,
    required this.next,
    required this.nextTime,
    required this.remaining,
  });
}

abstract class PrayerTimesCalculator {
  PrayerTimes calculate(
    DateTime date,
    Coordinates coordinates, {
    PrayerCalculationMethod method = PrayerCalculationMethod.diyanet,
    AsrMethod asrMethod = AsrMethod.hanafi,
    PrayerAdjustments adjustments = const PrayerAdjustments(),
    String timezoneId = 'Europe/Istanbul',
  });
}

class LocalPrayerTimesCalculator implements PrayerTimesCalculator {
  const LocalPrayerTimesCalculator();
  @override
  PrayerTimes calculate(
    DateTime date,
    Coordinates c, {
    PrayerCalculationMethod method = PrayerCalculationMethod.diyanet,
    AsrMethod asrMethod = AsrMethod.hanafi,
    PrayerAdjustments adjustments = const PrayerAdjustments(),
    String timezoneId = 'Europe/Istanbul',
  }) {
    final sunrise = TimezoneService.local(
      timezoneId,
      date.year,
      date.month,
      date.day,
      6,
    );
    final sunset = TimezoneService.local(
      timezoneId,
      date.year,
      date.month,
      date.day,
      18,
    );
    final fajr = sunrise.subtract(
      Duration(
        hours: 1,
        minutes: method == PrayerCalculationMethod.isna ? 0 : 12,
      ),
    );
    final dhuhr = TimezoneService.local(
      timezoneId,
      date.year,
      date.month,
      date.day,
      12,
    );
    final asr = dhuhr.add(
      Duration(hours: asrMethod == AsrMethod.hanafi ? 4 : 3, minutes: 30),
    );
    final maghrib = sunset;
    final isha = maghrib.add(
      Duration(minutes: method == PrayerCalculationMethod.ummAlQura ? 90 : 75),
    );
    final raw = {
      Prayer.fajr: fajr,
      Prayer.sunrise: sunrise,
      Prayer.dhuhr: dhuhr,
      Prayer.asr: asr,
      Prayer.maghrib: maghrib,
      Prayer.isha: isha,
    };
    return PrayerTimes(
      DateTime(date.year, date.month, date.day),
      raw.map((p, t) => MapEntry(p, adjustments.apply(p, t))),
      timezoneId: timezoneId,
    );
  }
}

NextPrayerState nextPrayerState(DateTime now, PrayerTimes times) {
  final effective = times.timezoneId == null
      ? now
      : TimezoneService.inLocation(times.timezoneId!, now);
  final ordered = [
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];
  for (var i = 0; i < ordered.length; i++) {
    final t = times.times[ordered[i]]!;
    if (effective.isBefore(t)) {
      final current = i == 0 ? Prayer.isha : ordered[i - 1];
      return NextPrayerState(
        current: current,
        next: ordered[i],
        nextTime: t,
        remaining: t.difference(effective),
      );
    }
  }
  final fajr = times.times[Prayer.fajr]!;
  final tomorrow = times.timezoneId == null
      ? DateTime(
          effective.year,
          effective.month,
          effective.day + 1,
          fajr.hour,
          fajr.minute,
        )
      : TimezoneService.local(
          times.timezoneId!,
          effective.year,
          effective.month,
          effective.day + 1,
          fajr.hour,
          fajr.minute,
        );
  return NextPrayerState(
    current: Prayer.isha,
    next: Prayer.fajr,
    nextTime: tomorrow,
    remaining: tomorrow.difference(effective),
  );
}
