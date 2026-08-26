import 'local_storage.dart';
import '../../features/content/domain/content_repository.dart';
import '../../features/premium/data/entitlement_repository.dart';
import '../../features/notifications/data/notification_preferences_repository.dart';
import '../../features/notifications/domain/notification_system.dart';
import '../../features/prayer_times/data/prayer_settings_repository.dart';
import '../../features/tasbih/data/tasbih_repository.dart';
import '../../features/tracker/data/prayer_tracker_repository.dart';

class LocalDataRepository {
  final LocalStorage storage;
  const LocalDataRepository(this.storage);
  Future<void> deleteAll() async {
    await storage.remove(PrayerSettingsRepository.key);
    await storage.remove(EntitlementRepository.key);
    await LocalTasbihRepository(storage).clear();
    await LocalPrayerTrackerRepository(storage).clear();
    await OfflineContentRepository(storage).clear();
    for (final prefix in [
      NotificationDataKeys.prefix,
      'dini.favorite.',
      'dini.widget.',
      'dini.premium.',
    ]) {
      await _removeKnownKeys(prefix);
    }
  }

  Future<void> _removeKnownKeys(String prefix) async {
    for (var index = 0; index < 400; index++) {
      await storage.remove('$prefix$index');
    }
    for (final suffix in [
      'friday',
      'ramadan.suhoor',
      'ramadan.iftar',
      'sound',
      'showLocation',
    ]) {
      await storage.remove('$prefix$suffix');
    }
    for (final prayer in notificationPrayers) {
      await storage.remove('$prefix${prayer.name}.enabled');
      await storage.remove('$prefix${prayer.name}.reminder');
    }
  }
}
