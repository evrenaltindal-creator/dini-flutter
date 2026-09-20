import '../../calendar/domain/islamic_calendar.dart';

/// Gecenin ait olduğu günün miladi tarihi.
///
/// Hicri gün akşam ezanıyla başlar: akşamdan sonraki gece ertesi güne
/// aittir. Teravih ve mahya bu yüzden akşamdan sonra bir gün ileriyi
/// gösterir; gece yarısından sonra takvim günü zaten ilerlemiştir.
DateTime ramadanNightDate(DateTime date, {required bool afterMaghrib}) {
  final today = DateTime(date.year, date.month, date.day);
  return afterMaghrib ? today.add(const Duration(days: 1)) : today;
}

/// Gecenin Ramazan'ın kaçıncı gecesi olduğu; Ramazan değilse null.
int? ramadanNightOf(
  DateTime date, {
  required bool afterMaghrib,
  IslamicCalendar calendar = const IslamicCalendar(),
}) {
  final hijri = calendar.hijri(
    ramadanNightDate(date, afterMaghrib: afterMaghrib),
  );
  return hijri.month == 9 ? hijri.day : null;
}
