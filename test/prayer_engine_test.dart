import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _calculator = LocalPrayerTimesCalculator();

const _istanbul = Coordinates(41.0082, 28.9784);
const _mecca = Coordinates(21.4225, 39.8262);
const _tromso = Coordinates(69.6492, 18.9553);

PrayerTimes _at(
  Coordinates where,
  DateTime date,
  String timezoneId, {
  PrayerCalculationMethod method = PrayerCalculationMethod.diyanet,
  AsrMethod asrMethod = AsrMethod.hanafi,
}) => _calculator.calculate(
  date,
  where,
  method: method,
  asrMethod: asrMethod,
  timezoneId: timezoneId,
);

int _minuteOfDay(DateTime value) => value.hour * 60 + value.minute;

const _ordered = [
  Prayer.fajr,
  Prayer.sunrise,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

void _expectOrdered(PrayerTimes times, String context) {
  for (var i = 1; i < _ordered.length; i++) {
    expect(
      times.times[_ordered[i]]!.isAfter(times.times[_ordered[i - 1]]!),
      isTrue,
      reason:
          '$context: ${_ordered[i].name}, ${_ordered[i - 1].name} '
          'vaktinden sonra gelmeli.',
    );
  }
}

void main() {
  setUpAll(TimezoneService.initialize);

  group('vakitler gerçekten hesaplanıyor', () {
    // Bu grubun tamamı, motorun koordinatı ve tarihi yok sayıp sabit saatler
    // döndürdüğü gerilemeye karşıdır. O sürümde bütün şehirler ve bütün
    // mevsimler aynı saatleri veriyordu.

    test('farklı şehirler farklı vakitler verir', () {
      final date = DateTime(2026, 6, 21);
      final istanbul = _at(_istanbul, date, 'Europe/Istanbul');
      final mecca = _at(_mecca, date, 'Asia/Riyadh');

      expect(
        _minuteOfDay(istanbul.times[Prayer.dhuhr]!),
        isNot(_minuteOfDay(mecca.times[Prayer.dhuhr]!)),
        reason: 'İstanbul ve Mekke aynı öğle vaktini veremez.',
      );
      expect(
        _minuteOfDay(istanbul.times[Prayer.maghrib]!),
        isNot(_minuteOfDay(mecca.times[Prayer.maghrib]!)),
      );
    });

    test('aynı şehirde mevsim vakitleri değiştirir', () {
      final summer = _at(_istanbul, DateTime(2026, 6, 21), 'Europe/Istanbul');
      final winter = _at(_istanbul, DateTime(2026, 12, 21), 'Europe/Istanbul');

      final summerDaylight = summer.times[Prayer.maghrib]!
          .difference(summer.times[Prayer.sunrise]!)
          .inMinutes;
      final winterDaylight = winter.times[Prayer.maghrib]!
          .difference(winter.times[Prayer.sunrise]!)
          .inMinutes;

      // İstanbul'da yaz gündüzü kış gündüzünden belirgin biçimde uzundur.
      expect(
        summerDaylight,
        greaterThan(winterDaylight + 120),
        reason: 'Yaz ve kış gündüz süresi neredeyse aynı çıkıyor.',
      );
    });

    test('boylam öğle vaktini kaydırır', () {
      // Aynı enlem, 30 derece doğuda bir nokta: güneş oraya yaklaşık iki saat
      // önce tepeye ulaşır. Koordinat yok sayılırsa bu fark sıfır olur.
      final date = DateTime(2026, 6, 21);
      final west = _at(const Coordinates(41.0, 0.0), date, 'UTC');
      final east = _at(const Coordinates(41.0, 30.0), date, 'UTC');

      final difference =
          _minuteOfDay(west.times[Prayer.dhuhr]!) -
          _minuteOfDay(east.times[Prayer.dhuhr]!);
      expect(difference, closeTo(120, 10));
    });
  });

  group('astronomik gerçeklik', () {
    test('İstanbul kışın geç doğar, yazın erken', () {
      final winter = _at(_istanbul, DateTime(2026, 12, 21), 'Europe/Istanbul');
      final summer = _at(_istanbul, DateTime(2026, 6, 21), 'Europe/Istanbul');

      // Türkiye yıl boyu UTC+3'te kaldığı için kış sabahları çok geçtir.
      expect(
        _minuteOfDay(winter.times[Prayer.sunrise]!),
        inInclusiveRange(480, 525),
      );
      expect(
        _minuteOfDay(summer.times[Prayer.sunrise]!),
        inInclusiveRange(300, 345),
      );
    });

    test('öğle vakti güneşin tepe noktasına yakındır', () {
      // İstanbul 28,98°D, saat dilimi UTC+3 (45°D meridyeni): güneş tepeye
      // yerel saatle 13:00 civarında ulaşır.
      final winter = _at(_istanbul, DateTime(2026, 12, 21), 'Europe/Istanbul');
      expect(
        _minuteOfDay(winter.times[Prayer.dhuhr]!),
        inInclusiveRange(765, 800),
      );
    });

    test('vakitler her mevsimde sıralıdır', () {
      for (final month in [1, 3, 6, 9, 12]) {
        _expectOrdered(
          _at(_istanbul, DateTime(2026, month, 15), 'Europe/Istanbul'),
          'İstanbul $month. ay',
        );
      }
    });
  });

  group('yöntem ve mezhep seçimleri etkili', () {
    final date = DateTime(2026, 6, 21);

    test('Hanefî ikindisi standart ikindiden sonradır', () {
      final hanafi = _at(
        _istanbul,
        date,
        'Europe/Istanbul',
        asrMethod: AsrMethod.hanafi,
      );
      final standard = _at(
        _istanbul,
        date,
        'Europe/Istanbul',
        asrMethod: AsrMethod.standard,
      );

      expect(
        hanafi.times[Prayer.asr]!.isAfter(standard.times[Prayer.asr]!),
        isTrue,
        reason: 'Hanefî gölge oranı ikindiyi geciktirmelidir.',
      );
    });

    test('ISNA sabahı Diyanet sabahından sonradır', () {
      // ISNA fecr açısı 15°, Diyanet 18°: daha küçük açı daha geç sabah demek.
      final isna = _at(
        _istanbul,
        date,
        'Europe/Istanbul',
        method: PrayerCalculationMethod.isna,
      );
      final diyanet = _at(_istanbul, date, 'Europe/Istanbul');

      expect(
        isna.times[Prayer.fajr]!.isAfter(diyanet.times[Prayer.fajr]!),
        isTrue,
      );
    });

    test('her yöntem sıralı ve makul vakitler üretir', () {
      for (final method in PrayerCalculationMethod.values) {
        _expectOrdered(
          _at(_istanbul, date, 'Europe/Istanbul', method: method),
          method.name,
        );
      }
    });
  });

  group('kutup bölgeleri', () {
    // Paketin kendi kutup koruması yalnızca değerler NaN olduğunda devreye
    // girer; Tromsø'da sonuçlar sayısal olarak geçerli ama sıralaması bozuk
    // çıkıyordu. Motor bunu kendi doğrulamasıyla yakalayıp enlemi kaydırır.

    test('kutup gecesi ve gece yarısı güneşinde sıra bozulmaz', () {
      _expectOrdered(
        _at(_tromso, DateTime(2026, 12, 21), 'Europe/Oslo'),
        'Tromsø kutup gecesi',
      );
      _expectOrdered(
        _at(_tromso, DateTime(2026, 6, 21), 'Europe/Oslo'),
        'Tromsø gece yarısı güneşi',
      );
    });

    test('kuzey Avrupa şehirleri yıl boyu sıralı kalır', () {
      const cities = {
        'Stockholm': [Coordinates(59.3293, 18.0686), 'Europe/Stockholm'],
        'Berlin': [Coordinates(52.52, 13.405), 'Europe/Berlin'],
        'Kiruna': [Coordinates(67.8558, 20.2253), 'Europe/Stockholm'],
      };
      cities.forEach((name, value) {
        for (final month in [1, 6, 12]) {
          _expectOrdered(
            _at(
              value[0] as Coordinates,
              DateTime(2026, month, 15),
              value[1] as String,
            ),
            '$name $month. ay',
          );
        }
      });
    });
  });

  test('dakika düzeltmeleri vakitleri tam olarak kaydırır', () {
    const adjustments = PrayerAdjustments(fajr: 3, dhuhr: -2, isha: 5);
    final plain = _at(_istanbul, DateTime(2026, 6, 21), 'Europe/Istanbul');
    final adjusted = _calculator.calculate(
      DateTime(2026, 6, 21),
      _istanbul,
      adjustments: adjustments,
      timezoneId: 'Europe/Istanbul',
    );

    expect(
      adjusted.times[Prayer.fajr]!
          .difference(plain.times[Prayer.fajr]!)
          .inMinutes,
      3,
    );
    expect(
      adjusted.times[Prayer.dhuhr]!
          .difference(plain.times[Prayer.dhuhr]!)
          .inMinutes,
      -2,
    );
    expect(
      adjusted.times[Prayer.isha]!
          .difference(plain.times[Prayer.isha]!)
          .inMinutes,
      5,
    );
  });
}
