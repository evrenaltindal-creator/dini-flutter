/// Takvim yaprağının halk takvimi satırları: Rumi tarih ve Hızır/Kasım
/// günleri.
///
/// **Rumi tarih** geleneksel (Jülyen tabanlı) hesaptır: gün ve ay Jülyen
/// takviminden gelir — bugün Miladi takvimden 13 gün geridedir — yıl Mart'ta
/// başlar ve Jülyen yılından 584 eksiktir (Mart 1840 = Rumi 1256). Hıdrellez'in
/// "Rumi 23 Nisan", Kasım gününün "Rumi 26 Teşrinievvel" diye anılması
/// buradandır. 1917'deki takvim düzenlemesinden sonraki resmî "Rumi" (Miladi
/// gün, Rumi yıl) başka bir hesaptır; halk takvimleri eskisini basar.
///
/// **Hızır ve Kasım günleri** yılı ikiye böler: Hıdrellez'den (6 Mayıs)
/// Kasım gününe (8 Kasım) kadar Hızır, sonrası Kasım günleridir; ilk gün 1
/// sayılır.
library;

/// Jülyen takviminde bir gün.
typedef JulianDate = ({int year, int month, int day});

/// Miladi tarihin Jülyen takvimindeki karşılığı.
///
/// Jülyen gün sayısı üzerinden çevrilir (Fliegel–Van Flandern); böylece iki
/// takvim arasındaki fark (şu an 13 gün, 2100'de 14) elle girilmez.
JulianDate julianFromGregorian(DateTime date) {
  final a = (14 - date.month) ~/ 12;
  final y = date.year + 4800 - a;
  final m = date.month + 12 * a - 3;
  final jdn =
      date.day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;

  final c = jdn + 32082;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final n = (5 * e + 2) ~/ 153;
  return (
    year: d - 4800 + n ~/ 10,
    month: n + 3 - 12 * (n ~/ 10),
    day: e - (153 * n + 2) ~/ 5 + 1,
  );
}

/// Rumi tarih. [month] Mart=3 ... Şubat=2 (Jülyen ay numarası).
class RumiDate {
  final int year;
  final int month;
  final int day;

  const RumiDate(this.year, this.month, this.day);

  factory RumiDate.fromGregorian(DateTime date) {
    final julian = julianFromGregorian(date);
    // Rumi yıl 1 Mart'ta başlar: Ocak ve Şubat bir önceki Rumi yıla aittir.
    final year = julian.month >= 3 ? julian.year - 584 : julian.year - 585;
    return RumiDate(year, julian.month, julian.day);
  }

  @override
  bool operator ==(Object other) =>
      other is RumiDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'RumiDate($day.$month.$year)';
}

/// Yılın hangi yarısı.
enum FolkSeason { hizir, kasim }

/// Hızır ya da Kasım'ın kaçıncı günü.
typedef FolkSeasonDay = ({FolkSeason season, int day});

/// Hıdrellez: Hızır günlerinin ilki.
const _hizirStart = (month: 5, day: 6);

/// Kasım günü: Kasım günlerinin ilki.
const _kasimStart = (month: 11, day: 8);

FolkSeasonDay folkSeasonDay(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final hizir = DateTime.utc(date.year, _hizirStart.month, _hizirStart.day);
  final kasim = DateTime.utc(date.year, _kasimStart.month, _kasimStart.day);

  if (!day.isBefore(hizir) && day.isBefore(kasim)) {
    return (season: FolkSeason.hizir, day: day.difference(hizir).inDays + 1);
  }
  // Kasım günleri yılı aşar: Ocak–Mayıs başı bir önceki yılın Kasım'ından
  // sayılır. UTC tarihle sayılır ki yaz saati bir günü yutmasın.
  final start = day.isBefore(hizir)
      ? DateTime.utc(date.year - 1, _kasimStart.month, _kasimStart.day)
      : kasim;
  return (season: FolkSeason.kasim, day: day.difference(start).inDays + 1);
}

/// Yılın kaçıncı günü ve yılın bitmesine kaç gün kaldığı.
({int dayOfYear, int daysLeft}) dayOfYear(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final first = DateTime.utc(date.year);
  final last = DateTime.utc(date.year, 12, 31);
  return (
    dayOfYear: day.difference(first).inDays + 1,
    daysLeft: last.difference(day).inDays,
  );
}
