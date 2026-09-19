import '../../../shared/models/domain.dart';
import 'prayer_engine.dart';
import 'prayer_settings.dart';

/// Bir ayın tamamı için günlük namaz vakitleri — imsakiye.
///
/// Vakitler tek tek hesaplanır; motor zaten tarihe ve koordinata bağlı
/// olduğundan ayın her günü kendi sonucunu verir. Ay listesi bilinçli olarak
/// sırayla üretilir: takvim günü sınırında (yaz saati geçişleri, kutup
/// düzeltmesi) bir günün sonucu diğerine sızmamalıdır.
class MonthlyTimetable {
  /// Ayın ilk günü (gün alanı her zaman 1).
  final DateTime month;

  /// Ayın günleri, 1. günden son güne kadar sırayla.
  final List<PrayerTimes> days;

  const MonthlyTimetable({required this.month, required this.days});

  /// [date] ayın içindeyse o günün vakitleri, değilse null.
  PrayerTimes? forDay(DateTime date) {
    if (date.year != month.year || date.month != month.month) return null;
    return days[date.day - 1];
  }
}

/// [month] ayının tamamı için vakitleri hesaplar.
///
/// [month] içindeki gün alanı yok sayılır; ayın ilk gününden son gününe
/// kadar hesaplanır.
MonthlyTimetable monthlyTimetable({
  required DateTime month,
  required Coordinates coordinates,
  PrayerCalculationMethod method = PrayerCalculationMethod.diyanet,
  AsrMethod asrMethod = AsrMethod.standard,
  PrayerAdjustments adjustments = const PrayerAdjustments(),
  String timezoneId = 'Europe/Istanbul',
  PrayerTimesCalculator calculator = const LocalPrayerTimesCalculator(),
}) {
  final first = DateTime(month.year, month.month);
  // Sonraki ayın sıfırıncı günü, bu ayın son günüdür; artık yılı da doğru verir.
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  return MonthlyTimetable(
    month: first,
    days: [
      for (var day = 1; day <= dayCount; day++)
        calculator.calculate(
          DateTime(first.year, first.month, day),
          coordinates,
          method: method,
          asrMethod: asrMethod,
          adjustments: adjustments,
          timezoneId: timezoneId,
        ),
    ],
  );
}
