import '../../../shared/models/domain.dart';

const trackedPrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

class PrayerTrackerDay {
  final DateTime date;
  final Map<Prayer, bool> completed;
  const PrayerTrackerDay(this.date, this.completed);
  int get completedCount =>
      trackedPrayers.where((prayer) => completed[prayer] == true).length;
  bool isCompleted(Prayer prayer) => completed[prayer] == true;
  PrayerTrackerDay toggle(Prayer prayer) =>
      PrayerTrackerDay(date, {...completed, prayer: !isCompleted(prayer)});
}

abstract class PrayerTrackerRepository {
  Future<PrayerTrackerDay> load(DateTime effectiveDate);
  Future<void> save(PrayerTrackerDay day);
  Future<List<PrayerTrackerDay>> recent(DateTime through, {int days = 7});
  Future<void> clear();
}
