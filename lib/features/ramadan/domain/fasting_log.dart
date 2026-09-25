import '../../calendar/domain/islamic_calendar.dart';

/// Bir günün oruç durumu.
enum FastingOutcome {
  /// Oruç tutuldu.
  fasted,

  /// Oruç tutulmadı.
  missed,
}

/// Orucun tutulmama sebebi.
///
/// Sebepler **kayıt içindir, hüküm değildir**. Uygulama tutulmayan bir orucun
/// kazasının gerekip gerekmediğine karar vermez; ekran kullanıcıyı Diyanet'e
/// sormaya yönlendirir.
enum FastingReason { illness, travel, menstruation, pregnancyOrNursing, other }

/// Bir günün kaydı.
class FastingEntry {
  final FastingOutcome outcome;

  /// Yalnızca [FastingOutcome.missed] için doludur.
  final FastingReason? reason;

  const FastingEntry(this.outcome, {this.reason});

  /// Depoya yazılan biçim.
  String encode() =>
      reason == null ? outcome.name : '${outcome.name}:${reason!.name}';

  /// Depodan okunan biçim; tanınmayan değer kayıt sayılmaz.
  static FastingEntry? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    final outcome = FastingOutcome.values
        .where((item) => item.name == parts.first)
        .firstOrNull;
    if (outcome == null) return null;
    final reason = parts.length > 1
        ? FastingReason.values
              .where((item) => item.name == parts[1])
              .firstOrNull
        : null;
    return FastingEntry(outcome, reason: reason);
  }

  @override
  bool operator ==(Object other) =>
      other is FastingEntry &&
      other.outcome == outcome &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(outcome, reason);
}

/// Bir Ramazan'ın takvimdeki yeri.
///
/// Ramazan 29 ya da 30 gün sürer ve hangisi olduğu tablodan bilinir; gün
/// sayısı hesaplanmaz, gerçekten sayılır.
class RamadanSpan {
  final int hijriYear;

  /// Ramazan'ın birinci gününün miladi karşılığı.
  final DateTime firstDay;

  /// Ramazan'ın gün sayısı (29 ya da 30).
  ///
  /// Uygulamanın tabular takviminde tek numaralı aylar otuz gün olduğu için
  /// bugün bu değer hep otuzdur. Yine de sayılarak bulunur: takvim gözleme
  /// dayalı bir kaynakla değiştirilirse sabit otuz son kutuyu bayramın
  /// birinci gününe kaydırırdı.
  final int length;

  const RamadanSpan({
    required this.hijriYear,
    required this.firstDay,
    required this.length,
  });

  /// [dayOfRamadan] gününün miladi karşılığı.
  DateTime dateOf(int dayOfRamadan) =>
      firstDay.add(Duration(days: dayOfRamadan - 1));

  /// Ramazan'ın son gününün miladi karşılığı.
  DateTime get lastDay => dateOf(length);
}

/// Bir gün Ramazan'ın içinde mi, değilse en son Ramazan hangisiydi?
///
/// Bayramda ve sonrasında da kayda bakılabilmeli: tutulmayan günleri görmek
/// asıl o zaman gerekir. Bu yüzden geriye doğru aranır, ileriye değil.
const _searchWindow = 400;

/// [date] gününü kapsayan ya da ondan önceki en son Ramazan.
RamadanSpan? ramadanSpanFor(
  DateTime date, {
  IslamicCalendar calendar = const IslamicCalendar(),
}) {
  final today = DateTime(date.year, date.month, date.day);
  DateTime? inside;
  for (var back = 0; back <= _searchWindow; back++) {
    final candidate = today.subtract(Duration(days: back));
    if (calendar.hijri(candidate).month == 9) {
      inside = candidate;
      break;
    }
  }
  if (inside == null) return null;

  var first = inside;
  while (calendar.hijri(first.subtract(const Duration(days: 1))).month == 9) {
    first = first.subtract(const Duration(days: 1));
  }
  var length = 1;
  while (calendar.hijri(first.add(Duration(days: length))).month == 9) {
    length++;
  }
  return RamadanSpan(
    hijriYear: calendar.hijri(first).year,
    firstDay: first,
    length: length,
  );
}

/// Bir Ramazan'ın oruç kaydı.
class FastingLog {
  final RamadanSpan span;
  final Map<int, FastingEntry> entries;

  const FastingLog({required this.span, this.entries = const {}});

  FastingEntry? entryOf(int dayOfRamadan) => entries[dayOfRamadan];

  int get fastedCount => entries.values
      .where((entry) => entry.outcome == FastingOutcome.fasted)
      .length;

  int get missedCount => entries.values
      .where((entry) => entry.outcome == FastingOutcome.missed)
      .length;

  /// Henüz işaretlenmemiş gün sayısı.
  int get unmarkedCount => span.length - entries.length;

  /// Kaydı değiştirir; [entry] null ise gün işaretsiz kalır.
  FastingLog withDay(int dayOfRamadan, FastingEntry? entry) {
    final next = {...entries};
    if (entry == null) {
      next.remove(dayOfRamadan);
    } else {
      next[dayOfRamadan] = entry;
    }
    return FastingLog(span: span, entries: next);
  }
}

/// [dayOfRamadan] günü işaretlenebilir mi?
///
/// Gelecek bir günün orucu işaretlenemez: tutulmamış bir orucu tutuldu diye
/// kaydetmek kaydın kendisini anlamsız kılar.
bool fastingDayIsMarkable(RamadanSpan span, int dayOfRamadan, DateTime today) {
  if (dayOfRamadan < 1 || dayOfRamadan > span.length) return false;
  final date = span.dateOf(dayOfRamadan);
  final day = DateTime(today.year, today.month, today.day);
  return !date.isAfter(day);
}
