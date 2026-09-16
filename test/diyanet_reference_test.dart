import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diyanet İşleri Başkanlığı'nın namazvakitleri.diyanet.gov.tr adresinde
/// Ankara için yayımladığı haftalık tablo (16-22 Eylül 2026).
///
/// Bu, motorun tek dış gerçeklik çıpasıdır: diğer testler iç tutarlılığı
/// ölçer, bu test hesabın resmî tabloyla örtüştüğünü ölçer. Sabit saatler
/// döndüren eski sürüm burada saatlerce sapardı.
const _ankara = Coordinates(39.9334, 32.8597);
const _timezone = 'Europe/Istanbul';

/// gün -> [imsak, güneş, öğle, ikindi, akşam, yatsı]
const _published = <int, List<String>>{
  16: ['04:58', '06:23', '12:49', '16:19', '19:04', '20:23'],
  17: ['05:00', '06:24', '12:48', '16:18', '19:02', '20:22'],
  18: ['05:01', '06:25', '12:48', '16:16', '19:01', '20:20'],
  19: ['05:02', '06:26', '12:48', '16:15', '18:59', '20:18'],
  20: ['05:03', '06:27', '12:47', '16:14', '18:57', '20:16'],
  21: ['05:04', '06:28', '12:47', '16:13', '18:56', '20:14'],
  22: ['05:05', '06:29', '12:46', '16:12', '18:54', '20:13'],
};

const _order = [
  Prayer.fajr,
  Prayer.sunrise,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];
const _names = ['imsak', 'güneş', 'öğle', 'ikindi', 'akşam', 'yatsı'];

/// Yayımlanan tabloyla izin verilen en büyük sapma.
///
/// Ölçülen fark günlere göre 0 ile 2 dakika arasında; yuvarlama ve Diyanet'in
/// şehir referans noktasından kaynaklanır. Üç dakika, gerçek bir gerilemeyi
/// (yanlış yöntem, yanlış mezhep, yanlış saat dilimi) yakalayacak kadar dar.
const _toleranceMinutes = 3;

int _minuteOfDay(DateTime value) => value.hour * 60 + value.minute;

int _parse(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

void main() {
  setUpAll(TimezoneService.initialize);

  group('Diyanet Ankara tablosu', () {
    const calculator = LocalPrayerTimesCalculator();

    PrayerTimes timesFor(int day, {AsrMethod? asrMethod}) =>
        calculator.calculate(
          DateTime(2026, 9, day),
          _ankara,
          asrMethod: asrMethod ?? const PrayerSettings().asrMethod,
          timezoneId: _timezone,
        );

    _published.forEach((day, expected) {
      test('$day Eylül 2026 vakitleri tabloyla örtüşür', () {
        final times = timesFor(day);
        for (var i = 0; i < _order.length; i++) {
          final actual = _minuteOfDay(times.times[_order[i]]!);
          final published = _parse(expected[i]);
          expect(
            (actual - published).abs(),
            lessThanOrEqualTo(_toleranceMinutes),
            reason:
                '$day Eylül ${_names[i]}: hesaplanan '
                '${actual ~/ 60}:${(actual % 60).toString().padLeft(2, '0')}, '
                'Diyanet ${expected[i]}.',
          );
        }
      });
    });

    test('varsayılan mezhep Diyanet tablosunu verir, Hanefî ikindisi geç', () {
      // Diyanet ikindiyi asr-ı evvel (gölge oranı 1) ile yayımlar. Varsayılan
      // Hanefî iken tablo ile aramızda ~52 dakika fark oluşuyordu.
      final standard = timesFor(16, asrMethod: AsrMethod.standard);
      final hanafi = timesFor(16, asrMethod: AsrMethod.hanafi);
      final published = _parse('16:19');

      expect(
        (_minuteOfDay(standard.times[Prayer.asr]!) - published).abs(),
        lessThanOrEqualTo(_toleranceMinutes),
      );
      expect(
        _minuteOfDay(hanafi.times[Prayer.asr]!) - published,
        greaterThan(30),
        reason: 'Hanefî ikindisi tablodan belirgin biçimde sonradır.',
      );
      expect(
        const PrayerSettings().asrMethod,
        AsrMethod.standard,
        reason: 'Varsayılan, Diyanet tablosuyla örtüşen hesap olmalıdır.',
      );
    });

    test('güneş ve akşam, astronomik değerlerden 7 dakika kaydırılır', () {
      // Diyanet aynı sayfada 16 Eylül için astronomik doğuşu 06:30, batışı
      // 18:57 veriyor; yayımladığı güneş 06:23 ve akşam 19:04. Yani yöntem
      // doğuşu 7 dakika öne, akşamı 7 dakika arkaya alıyor. Motorun bu
      // düzeltmeleri uyguladığını doğrular.
      final times = timesFor(16);
      expect(
        (_minuteOfDay(times.times[Prayer.sunrise]!) - (_parse('06:30') - 7))
            .abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        (_minuteOfDay(times.times[Prayer.maghrib]!) - (_parse('18:57') + 7))
            .abs(),
        lessThanOrEqualTo(1),
      );
    });
  });
}
