class IslamicDate {
  final int year, month, day;
  const IslamicDate(this.year, this.month, this.day);
  String get label => '$day/$month/$year';
}

class IslamicCalendar {
  const IslamicCalendar();
  IslamicDate hijri(DateTime date) {
    final jd = _julianDay(date.year, date.month, date.day);
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j =
        ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l =
        l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return IslamicDate(year, month, day);
  }

  bool isFriday(DateTime date) => date.weekday == DateTime.friday;
  bool isRamadan(DateTime date) {
    final h = hijri(date);
    return h.month == 9;
  }

  int? ramadanDay(DateTime date) {
    final h = hijri(date);
    return isRamadan(date) ? h.day : null;
  }

  int _julianDay(int y, int m, int d) {
    if (m <= 2) {
      y--;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + (a ~/ 4);
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524;
  }
}
