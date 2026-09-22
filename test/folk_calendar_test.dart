import 'package:dini_flutter/features/calendar/domain/folk_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rumi tarih', () {
    test('halk takviminin bilinen noktalarıyla uyuşur', () {
      // Hıdrellez "Rumi 23 Nisan" diye anılır ve 6 Mayıs'a düşer; Kasım
      // günü "Rumi 26 Teşrinievvel" = 8 Kasım; Nevruz "Rumi 9 Mart" = 22 Mart.
      expect(
        RumiDate.fromGregorian(DateTime(2026, 5, 6)),
        const RumiDate(1442, 4, 23),
      );
      expect(
        RumiDate.fromGregorian(DateTime(2026, 11, 8)),
        const RumiDate(1442, 10, 26),
      );
      expect(
        RumiDate.fromGregorian(DateTime(2026, 3, 22)),
        const RumiDate(1442, 3, 9),
      );
    });

    test('yıl Mart\'ta başlar', () {
      // 1 Ocak 2024 Jülyen'de 19 Aralık 2023'tür: Rumi 1439.
      expect(
        RumiDate.fromGregorian(DateTime(2024, 1, 1)),
        const RumiDate(1439, 12, 19),
      );
      // Rumi 1 Mart 1440, Miladi 14 Mart 2024'tür.
      expect(
        RumiDate.fromGregorian(DateTime(2024, 3, 14)),
        const RumiDate(1440, 3, 1),
      );
      expect(
        RumiDate.fromGregorian(DateTime(2024, 3, 13)),
        const RumiDate(1439, 2, 29),
        reason: 'Jülyen takviminde 2024 artık yıldır: 29 Şubat var.',
      );
    });

    test('Rumi 1256 Mart 1840\'ta başlar', () {
      // 1 Mart 1840 Jülyen = 13 Mart 1840 Miladi (fark o zaman 12 gün).
      expect(
        RumiDate.fromGregorian(DateTime(1840, 3, 13)),
        const RumiDate(1256, 3, 1),
      );
    });

    test('iki takvim arasındaki fark elle girilmedi: 2100\'de 14 gün olur', () {
      // 2100 Jülyen takviminde artık yıl, Miladi'de değil: Jülyen 29 Şubat
      // Miladi 14 Mart'a düşer ve fark o günden sonra 14 olur.
      final before = julianFromGregorian(DateTime(2100, 2, 28));
      expect([before.month, before.day], [2, 15]); // fark 13
      final leap = julianFromGregorian(DateTime(2100, 3, 14));
      expect([leap.month, leap.day], [2, 29]);
      final after = julianFromGregorian(DateTime(2100, 3, 15));
      expect([after.month, after.day], [3, 1]); // fark 14
    });
  });

  group('Hızır ve Kasım günleri', () {
    test('Hıdrellez Hızır\'ın, 8 Kasım Kasım\'ın ilk günü', () {
      expect(folkSeasonDay(DateTime(2026, 5, 6)), (
        season: FolkSeason.hizir,
        day: 1,
      ));
      expect(folkSeasonDay(DateTime(2026, 11, 7)), (
        season: FolkSeason.hizir,
        day: 186,
      ));
      expect(folkSeasonDay(DateTime(2026, 11, 8)), (
        season: FolkSeason.kasim,
        day: 1,
      ));
    });

    test('Kasım günleri yılı aşar ve artık yılda bir gün uzar', () {
      expect(folkSeasonDay(DateTime(2027, 5, 5)), (
        season: FolkSeason.kasim,
        day: 179,
      ));
      expect(folkSeasonDay(DateTime(2028, 5, 5)), (
        season: FolkSeason.kasim,
        day: 180,
      ));
      expect(folkSeasonDay(DateTime(2027, 1, 1)).season, FolkSeason.kasim);
    });

    test('yaz saati bir günü yutmaz', () {
      // Yerel saatle gün farkı yaz saati gecesi 23 saat sürer; UTC ile
      // sayılır.
      final days = [
        for (var d = 20; d <= 31; d++) folkSeasonDay(DateTime(2027, 3, d)).day,
      ];
      for (var i = 1; i < days.length; i++) {
        expect(days[i] - days[i - 1], 1);
      }
    });
  });

  test('yılın günü ve kalan gün', () {
    expect(dayOfYear(DateTime(2026, 1, 1)), (dayOfYear: 1, daysLeft: 364));
    expect(dayOfYear(DateTime(2026, 9, 22)), (dayOfYear: 265, daysLeft: 100));
    expect(dayOfYear(DateTime(2028, 12, 31)), (dayOfYear: 366, daysLeft: 0));
  });
}
