import 'package:adhan_dart/adhan_dart.dart' as adhan;

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
    required this.current,
    required this.next,
    required this.nextTime,
    required this.remaining,
  });
}

abstract class PrayerTimesCalculator {
  PrayerTimes calculate(
    DateTime date,
    Coordinates coordinates, {
    PrayerCalculationMethod method,
    AsrMethod asrMethod,
    PrayerAdjustments adjustments,
    String timezoneId,
  });
}

/// Namaz vakitlerini gerçek güneş konumundan hesaplar.
///
/// Hesap `adhan_dart` paketine devredilir: kıble ve namaz vakti matematiği
/// dinî açıdan kritiktir ve bağımsız olarak denenmiş bir uygulamayı kullanmak,
/// astronomiyi elle yazmaktan güvenlidir. Paket saf Dart'tır, ağ veya platform
/// bağımlılığı yoktur; uygulamanın çevrimdışı çalışma kuralı korunur.
///
/// Sonuçlar paket tarafından UTC olarak üretilir ve burada namaz konumunun
/// IANA saat dilimine çevrilir, ardından kullanıcının dakika düzeltmeleri
/// uygulanır.
class LocalPrayerTimesCalculator implements PrayerTimesCalculator {
  const LocalPrayerTimesCalculator();

  /// Kutup bölgesinde enlemi ekvatora doğru kaydırma adımı ve üst sınırı.
  /// 0,5°'lik adımlarla en çok 30° kaydırılır; bu, en kuzeydeki yerleşimleri
  /// bile vakitlerin hesaplanabildiği bir enleme taşımaya yeter.
  static const _latitudeStep = 0.5;
  static const _maxLatitudeSteps = 60;

  @override
  PrayerTimes calculate(
    DateTime date,
    Coordinates coordinates, {
    PrayerCalculationMethod method = PrayerCalculationMethod.diyanet,
    AsrMethod asrMethod = AsrMethod.hanafi,
    PrayerAdjustments adjustments = const PrayerAdjustments(),
    String timezoneId = 'Europe/Istanbul',
  }) {
    var latitude = coordinates.latitude;
    var times = _compute(
      latitude,
      coordinates.longitude,
      date,
      method,
      asrMethod,
      timezoneId,
    );

    // Kutup dairesinde güneş gerekli açılara hiç ulaşmayabilir. Paketin kendi
    // koruması yalnızca değerler NaN olduğunda devreye girer; Tromsø'da
    // 21 Aralık'ta sonuçlar sayısal olarak geçerli ama sıralaması bozuk
    // çıkıyordu (güneş öğleden sonra, akşam sabahtan önce). Bu yüzden sonucu
    // doğrular, bozuksa enlemi ekvatora doğru kaydırıp yeniden hesaplarız:
    // "en yakın yer" (aqrab al-balad) yaklaşımı. Boylam ve saat dilimi korunur,
    // böylece takvim günü kaymaz.
    for (var step = 0; step < _maxLatitudeSteps && !_isOrdered(times); step++) {
      latitude = _towardEquator(latitude);
      times = _compute(
        latitude,
        coordinates.longitude,
        date,
        method,
        asrMethod,
        timezoneId,
      );
    }

    return PrayerTimes(
      DateTime(date.year, date.month, date.day),
      times.map(
        (prayer, time) => MapEntry(prayer, adjustments.apply(prayer, time)),
      ),
      timezoneId: timezoneId,
    );
  }

  Map<Prayer, DateTime> _compute(
    double latitude,
    double longitude,
    DateTime date,
    PrayerCalculationMethod method,
    AsrMethod asrMethod,
    String timezoneId,
  ) {
    final position = adhan.Coordinates(latitude, longitude);
    final parameters = _parametersFor(method)
      ..madhab = asrMethod == AsrMethod.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi
      ..highLatitudeRule = adhan.HighLatitudeRule.recommended(position)
      ..polarCircleResolution = adhan.PolarCircleResolution.aqrabBalad;

    final computed = adhan.PrayerTimes(
      date: DateTime.utc(date.year, date.month, date.day),
      coordinates: position,
      calculationParameters: parameters,
    );

    DateTime at(DateTime value) =>
        TimezoneService.inLocation(timezoneId, value);

    return <Prayer, DateTime>{
      Prayer.fajr: at(computed.fajr),
      Prayer.sunrise: at(computed.sunrise),
      Prayer.dhuhr: at(computed.dhuhr),
      Prayer.asr: at(computed.asr),
      Prayer.maghrib: at(computed.maghrib),
      Prayer.isha: at(computed.isha),
    };
  }

  /// Vakitler gün içinde artan sırada mı? Kutup gecesinde bu bozulur.
  static bool _isOrdered(Map<Prayer, DateTime> times) {
    const order = [
      Prayer.fajr,
      Prayer.sunrise,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ];
    for (var i = 1; i < order.length; i++) {
      if (!times[order[i]]!.isAfter(times[order[i - 1]]!)) return false;
    }
    return true;
  }

  static double _towardEquator(double latitude) => latitude > 0
      ? (latitude - _latitudeStep).clamp(0, 90).toDouble()
      : (latitude + _latitudeStep).clamp(-90, 0).toDouble();

  /// Uygulamanın yöntem seçimini paketin parametre kümesine eşler.
  ///
  /// Diyanet için paketin `turkiye` kümesi kullanılır: fecr 18°, yatsı 17° ve
  /// Diyanet'in yayımlanmış dakika düzeltmeleri.
  adhan.CalculationParameters _parametersFor(PrayerCalculationMethod method) =>
      switch (method) {
        PrayerCalculationMethod.diyanet =>
          adhan.CalculationMethodParameters.turkiye(),
        PrayerCalculationMethod.muslimWorldLeague =>
          adhan.CalculationMethodParameters.muslimWorldLeague(),
        PrayerCalculationMethod.ummAlQura =>
          adhan.CalculationMethodParameters.ummAlQura(),
        PrayerCalculationMethod.egyptian =>
          adhan.CalculationMethodParameters.egyptian(),
        PrayerCalculationMethod.karachi =>
          adhan.CalculationMethodParameters.karachi(),
        PrayerCalculationMethod.isna =>
          adhan.CalculationMethodParameters.northAmerica(),
      };
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
