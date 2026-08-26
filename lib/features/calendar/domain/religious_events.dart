import 'islamic_calendar.dart';

class IslamicEvent {
  final String id, name;
  final int hijriMonth, hijriDay;
  const IslamicEvent(this.id, this.name, this.hijriMonth, this.hijriDay);
}

class NextIslamicEvent {
  final IslamicEvent event;
  final DateTime date;
  final int daysRemaining;
  const NextIslamicEvent(this.event, this.date, this.daysRemaining);
}

class ReligiousEvents {
  final IslamicCalendar calendar;
  const ReligiousEvents({this.calendar = const IslamicCalendar()});
  static const events = [
    IslamicEvent('ramadan-start', 'Ramazan başlangıcı', 9, 1),
    IslamicEvent('laylat-al-qadr', 'Kadir Gecesi', 9, 27),
    IslamicEvent('eid-al-fitr', 'Ramazan Bayramı', 10, 1),
    IslamicEvent('eid-al-adha', 'Kurban Bayramı', 12, 10),
    IslamicEvent('mawlid', 'Mevlid Kandili', 3, 12),
    IslamicEvent('miraj', 'Miraç Kandili', 7, 27),
    IslamicEvent('berat', 'Berat Kandili', 8, 15),
  ];
  List<IslamicEvent> on(DateTime date) {
    final h = calendar.hijri(date);
    return events
        .where(
          (event) => event.hijriMonth == h.month && event.hijriDay == h.day,
        )
        .toList();
  }

  NextIslamicEvent next(DateTime from, {int maxDays = 400}) {
    for (var index = 0; index <= maxDays; index++) {
      final date = DateTime(from.year, from.month, from.day + index);
      final matches = on(date);
      if (matches.isNotEmpty) {
        return NextIslamicEvent(matches.first, date, index);
      }
    }
    throw StateError('No Islamic event found in search window');
  }
}
