import '../../../shared/models/domain.dart';

class PrayerAdjustments {
  final int fajr, dhuhr, asr, maghrib, isha;
  const PrayerAdjustments({
    this.fajr = 0,
    this.dhuhr = 0,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
  });
  DateTime apply(Prayer prayer, DateTime value) {
    final minutes = switch (prayer) {
      Prayer.fajr => fajr,
      Prayer.dhuhr => dhuhr,
      Prayer.asr => asr,
      Prayer.maghrib => maghrib,
      Prayer.isha => isha,
      Prayer.sunrise => 0,
    };
    return value.add(Duration(minutes: minutes));
  }
}

enum LocationMode { automatic, manual }

class PrayerSettings {
  final PrayerCalculationMethod method;
  final AsrMethod asrMethod;
  final bool use24Hour;
  final LocationPreference location;
  final LocationMode locationMode;
  final PrayerAdjustments adjustments;
  const PrayerSettings({
    this.method = PrayerCalculationMethod.diyanet,
    // Diyanet yayımladığı ikindi vaktini standart (asr-ı evvel, gölge oranı 1)
    // hesabıyla verir. Varsayılan Hanefî iken uygulamanın ikindisi Diyanet'in
    // tablosundan ~52 dakika sonra çıkıyordu; Ankara 16-22 Eylül 2026 verisiyle
    // ölçüldü. Hanefî (asr-ı sânî) seçeneği Ayarlar'da duruyor.
    this.asrMethod = AsrMethod.standard,
    this.use24Hour = true,
    this.location = const LocationPreference(
      city: 'Istanbul',
      latitude: 41.0082,
      longitude: 28.9784,
      timezoneId: 'Europe/Istanbul',
    ),
    this.locationMode = LocationMode.manual,
    this.adjustments = const PrayerAdjustments(),
  });
  PrayerSettings copyWith({
    PrayerCalculationMethod? method,
    AsrMethod? asrMethod,
    bool? use24Hour,
    LocationPreference? location,
    LocationMode? locationMode,
    PrayerAdjustments? adjustments,
  }) => PrayerSettings(
    method: method ?? this.method,
    asrMethod: asrMethod ?? this.asrMethod,
    use24Hour: use24Hour ?? this.use24Hour,
    location: location ?? this.location,
    locationMode: locationMode ?? this.locationMode,
    adjustments: adjustments ?? this.adjustments,
  );
}

String formatPrayerTime(DateTime value, {bool use24Hour = true}) {
  if (use24Hour) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$h:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
}
