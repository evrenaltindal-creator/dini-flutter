import 'prayer_tracker.dart';

/// Gün tamamlanmış sayılır mı?
///
/// Beş vaktin hepsi işaretlenmelidir. Daha gevşek bir ölçü (örneğin üç vakit)
/// seriyi anlamsız kılardı: seri, kullanıcının kendi koyduğu ölçüyü değil,
/// günün tamamlanmasını sayar.
bool trackerDayIsComplete(PrayerTrackerDay day) =>
    day.completedCount == trackedPrayers.length;

/// Seri özeti.
class StreakSummary {
  /// Bugüne kadar kesintisiz tamamlanan gün sayısı.
  final int current;

  /// Kayıttaki en uzun kesintisiz seri.
  final int longest;

  /// Kayıtta tamamlanan toplam gün.
  final int completedDays;

  const StreakSummary({
    required this.current,
    required this.longest,
    required this.completedDays,
  });

  static const empty = StreakSummary(current: 0, longest: 0, completedDays: 0);
}

/// [days] listesinden seriyi çıkarır.
///
/// Liste sırasız gelebilir; burada tarihe göre yeniden sıralanır.
///
/// **Bugün henüz tamamlanmamışsa seri bozulmaz.** Gün bitmeden "seriyi
/// kaybettin" demek, sabah namazından sonra uygulamayı açan herkese yanlış
/// söylerdi; bugün seriye ancak tamamlandığında eklenir.
StreakSummary streakOf(List<PrayerTrackerDay> days, {required DateTime today}) {
  if (days.isEmpty) return StreakSummary.empty;

  final day = DateTime(today.year, today.month, today.day);
  final completed = <DateTime>{
    for (final item in days)
      if (trackerDayIsComplete(item))
        DateTime(item.date.year, item.date.month, item.date.day),
  };
  if (completed.isEmpty) return StreakSummary.empty;

  // Güncel seri: bugünden (ya da bugün boşsa dünden) geriye doğru sayılır.
  var cursor = completed.contains(day)
      ? day
      : day.subtract(const Duration(days: 1));
  var current = 0;
  while (completed.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // En uzun seri: tamamlanan günler sıralanıp ardışık olanlar sayılır.
  final sorted = completed.toList()..sort();
  var longest = 1;
  var run = 1;
  for (var index = 1; index < sorted.length; index++) {
    final gap = sorted[index].difference(sorted[index - 1]).inDays;
    run = gap == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  return StreakSummary(
    current: current,
    longest: longest > current ? longest : current,
    completedDays: completed.length,
  );
}

/// Isı haritasının tek bir günü.
class HeatmapCell {
  final DateTime date;

  /// O gün işaretlenen vakit sayısı (0–5).
  final int completed;

  const HeatmapCell(this.date, this.completed);

  /// Renk yoğunluğu: 0 boş, 1 tam.
  double get intensity => completed / trackedPrayers.length;
}

/// Isı haritasında gösterilen hafta sayısı.
const heatmapWeeks = 17;

/// Günleri haftalara böler; her hafta pazartesiden pazara yedi hücredir.
///
/// Hücre null olabilir: ilk haftanın başındaki boşluklar ve bugünden sonraki
/// günler. Gelecek günler boş bırakılır, sıfırla doldurulmaz — tutulmamış bir
/// gün ile henüz gelmemiş bir gün aynı şey değildir.
List<List<HeatmapCell?>> heatmapOf(
  List<PrayerTrackerDay> days, {
  required DateTime today,
  int weeks = heatmapWeeks,
}) {
  final last = DateTime(today.year, today.month, today.day);
  // Son hafta bugünü içerecek şekilde geriye doğru gidilir ve başlangıç
  // pazartesiye çekilir; aksi halde sütunlar haftanın ortasından başlar.
  final rawStart = last.subtract(Duration(days: weeks * 7 - 1));
  final start = rawStart.subtract(Duration(days: rawStart.weekday - 1));

  final counts = <DateTime, int>{
    for (final item in days)
      DateTime(item.date.year, item.date.month, item.date.day):
          item.completedCount,
  };

  final result = <List<HeatmapCell?>>[];
  var cursor = start;
  while (!cursor.isAfter(last)) {
    final week = <HeatmapCell?>[];
    for (var index = 0; index < 7; index++) {
      final date = cursor.add(Duration(days: index));
      week.add(
        date.isAfter(last) ? null : HeatmapCell(date, counts[date] ?? 0),
      );
    }
    result.add(week);
    cursor = cursor.add(const Duration(days: 7));
  }
  return result;
}
