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
/// [exempt] günleri seriyi **bozmaz ve seriye eklemez**: o günlerde namaz
/// kılınmadığı için eksik kalan bir şey yoktur. Seri muaf günün üzerinden
/// atlayarak devam eder.
///
/// Liste sırasız gelebilir; burada tarihe göre yeniden sıralanır.
///
/// **Bugün henüz tamamlanmamışsa seri bozulmaz.** Gün bitmeden "seriyi
/// kaybettin" demek, sabah namazından sonra uygulamayı açan herkese yanlış
/// söylerdi; bugün seriye ancak tamamlandığında eklenir.
StreakSummary streakOf(
  List<PrayerTrackerDay> days, {
  required DateTime today,
  Set<DateTime> exempt = const {},
}) {
  if (days.isEmpty) return StreakSummary.empty;

  final day = DateTime(today.year, today.month, today.day);
  final completed = <DateTime>{
    for (final item in days)
      if (trackerDayIsComplete(item))
        DateTime(item.date.year, item.date.month, item.date.day),
  };
  if (completed.isEmpty) return StreakSummary.empty;

  final exemptDays = {
    for (final date in exempt) DateTime(date.year, date.month, date.day),
  };

  // Arama elde veri olan en eski günde durur; her günü muaf olan bir kayıt
  // aksi halde sonsuza kadar geriye giderdi.
  final known = [...completed, ...exemptDays]..sort();
  final earliest = known.first;

  // Güncel seri: bugünden geriye doğru sayılır. Bugün ne tamamlanmış ne de
  // muafsa dünden başlanır — gün bitmeden seri bozulmamalı.
  var cursor = completed.contains(day) || exemptDays.contains(day)
      ? day
      : day.subtract(const Duration(days: 1));
  var current = 0;
  while (!cursor.isBefore(earliest)) {
    if (exemptDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    if (!completed.contains(cursor)) break;
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // En uzun seri: en eski günden bugüne yürünür. Muaf gün seriyi taşır ama
  // sayıya eklenmez.
  var longest = 0;
  var run = 0;
  for (
    var date = earliest;
    !date.isAfter(day);
    date = date.add(const Duration(days: 1))
  ) {
    if (exemptDays.contains(date)) continue;
    if (completed.contains(date)) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
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

  /// Namaz kılınmayan (muaf) gün mü? Boş günden ayrı gösterilir: eksik
  /// kalan bir şey yoktur.
  final bool exempt;

  const HeatmapCell(this.date, this.completed, {this.exempt = false});

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
  Set<DateTime> exempt = const {},
  int weeks = heatmapWeeks,
}) {
  final last = DateTime(today.year, today.month, today.day);
  // Son hafta bugünü içerecek şekilde geriye doğru gidilir ve başlangıç
  // pazartesiye çekilir; aksi halde sütunlar haftanın ortasından başlar.
  final rawStart = last.subtract(Duration(days: weeks * 7 - 1));
  final start = rawStart.subtract(Duration(days: rawStart.weekday - 1));

  final exemptDays = {
    for (final date in exempt) DateTime(date.year, date.month, date.day),
  };
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
        date.isAfter(last)
            ? null
            : HeatmapCell(
                date,
                counts[date] ?? 0,
                exempt: exemptDays.contains(date),
              ),
      );
    }
    result.add(week);
    cursor = cursor.add(const Duration(days: 7));
  }
  return result;
}
