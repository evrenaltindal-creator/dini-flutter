import '../../../core/storage/local_storage.dart';
import '../../../shared/models/domain.dart';
import '../domain/prayer_tracker.dart';

class LocalPrayerTrackerRepository implements PrayerTrackerRepository {
  final LocalStorage storage;
  const LocalPrayerTrackerRepository(this.storage);
  static const prefix = 'dini.tracker.';
  @override
  Future<PrayerTrackerDay> load(DateTime effectiveDate) async {
    final date = _dateKey(effectiveDate);
    final values = <Prayer, bool>{};
    for (final prayer in trackedPrayers) {
      values[prayer] = await storage.read('$prefix$date.${prayer.name}') == '1';
    }
    return PrayerTrackerDay(
      DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day),
      values,
    );
  }

  @override
  Future<void> save(PrayerTrackerDay day) async {
    final date = _dateKey(day.date);
    for (final prayer in trackedPrayers) {
      final key = '$prefix$date.${prayer.name}';
      if (day.isCompleted(prayer)) {
        await storage.write(key, '1');
      } else {
        await storage.remove(key);
      }
    }
  }

  @override
  Future<List<PrayerTrackerDay>> recent(
    DateTime through, {
    int days = 7,
  }) async {
    final result = <PrayerTrackerDay>[];
    for (var index = 0; index < days; index++) {
      result.add(
        await load(DateTime(through.year, through.month, through.day - index)),
      );
    }
    return result;
  }

  @override
  Future<void> clear() async {
    final keys = <String>[];
    for (final date in List.generate(
      370,
      (index) => DateTime.now().subtract(Duration(days: index)),
    )) {
      for (final prayer in trackedPrayers) {
        keys.add('$prefix${_dateKey(date)}.${prayer.name}');
      }
    }
    for (final key in keys) {
      await storage.remove(key);
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
