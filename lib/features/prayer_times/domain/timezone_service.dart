import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  static bool _ready = false;
  const TimezoneService();
  static void initialize() {
    if (!_ready) {
      tzdata.initializeTimeZones();
      _ready = true;
    }
  }

  static tz.Location location(String id) {
    initialize();
    try {
      return tz.getLocation(id);
    } catch (_) {
      throw FormatException('Unknown timezone id: $id');
    }
  }

  static bool isValid(String id) {
    try {
      location(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static DateTime local(
    String id,
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) => tz.TZDateTime(location(id), year, month, day, hour, minute, second);
  static DateTime nextDay(String id, DateTime value) => local(
    id,
    value.year,
    value.month,
    value.day + 1,
    value.hour,
    value.minute,
    value.second,
  );
  static DateTime inLocation(String id, DateTime value) =>
      tz.TZDateTime.from(value, location(id));
}
