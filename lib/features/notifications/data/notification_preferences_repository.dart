import '../../../core/storage/local_storage.dart';
import '../../../shared/models/domain.dart';
import '../domain/notification_system.dart';

class NotificationPreferencesRepository {
  final LocalStorage storage;
  const NotificationPreferencesRepository(this.storage);
  static const _prefix = 'dini.notifications.';
  Future<NotificationPreferences> load() async {
    final prayers = <Prayer, PrayerNotificationPreference>{};
    for (final prayer in notificationPrayers) {
      final enabled =
          await storage.read('$_prefix${prayer.name}.enabled') == '1';
      final raw = await storage.read('$_prefix${prayer.name}.reminder');
      prayers[prayer] = PrayerNotificationPreference(
        enabled: enabled,
        reminderMinutes: raw == null ? null : int.tryParse(raw),
      );
    }
    final sound = NotificationSound
        .values[int.tryParse(await storage.read('${_prefix}sound') ?? '') ?? 0];
    return NotificationPreferences(
      prayers: prayers,
      sound: sound,
      fridayReminder: await _bool('friday'),
      ramadanSuhoorReminder: await _bool('ramadan.suhoor'),
      ramadanIftarReminder: await _bool('ramadan.iftar'),
      suhoorMinutes: await _minutes('ramadan.suhoor.minutes', 45),
      iftarMinutes: await _minutes('ramadan.iftar.minutes', 30),
    );
  }

  Future<void> save(NotificationPreferences value) async {
    for (final prayer in notificationPrayers) {
      final setting = value.forPrayer(prayer);
      await storage.write(
        '$_prefix${prayer.name}.enabled',
        setting.enabled ? '1' : '0',
      );
      final key = '$_prefix${prayer.name}.reminder';
      if (setting.reminderMinutes == null) {
        await storage.remove(key);
      } else {
        await storage.write(key, '${setting.reminderMinutes}');
      }
    }
    await storage.write('${_prefix}sound', '${value.sound.index}');
    await storage.write('${_prefix}friday', value.fridayReminder ? '1' : '0');
    await storage.write(
      '${_prefix}ramadan.suhoor',
      value.ramadanSuhoorReminder ? '1' : '0',
    );
    await storage.write(
      '${_prefix}ramadan.iftar',
      value.ramadanIftarReminder ? '1' : '0',
    );
    await storage.write(
      '${_prefix}ramadan.suhoor.minutes',
      '${value.suhoorMinutes}',
    );
    await storage.write(
      '${_prefix}ramadan.iftar.minutes',
      '${value.iftarMinutes}',
    );
  }

  /// Kayıtlı dakika değeri. Hiç kaydedilmemişse ya da bozuksa varsayılan
  /// döner; bozuk bir değer uyarıyı hiç göndermemeye yol açmamalı.
  Future<int> _minutes(String key, int fallback) async =>
      int.tryParse(await storage.read('$_prefix$key') ?? '') ?? fallback;

  Future<bool> _bool(String key) async =>
      await storage.read('$_prefix$key') == '1';
}

class NotificationDataKeys {
  static const prefix = NotificationPreferencesRepository._prefix;
}
