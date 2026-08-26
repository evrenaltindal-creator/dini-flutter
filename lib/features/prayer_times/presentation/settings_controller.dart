import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/local_storage.dart';
import '../data/prayer_settings_repository.dart';
import '../domain/prayer_settings.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences override required'),
);
final prayerSettingsRepositoryProvider = Provider<PrayerSettingsRepository>(
  (ref) => PrayerSettingsRepository(
    SharedPreferencesStorage(ref.watch(sharedPreferencesProvider)),
  ),
);
final prayerSettingsProvider =
    AsyncNotifierProvider<PrayerSettingsController, PrayerSettings>(
      PrayerSettingsController.new,
    );

class PrayerSettingsController extends AsyncNotifier<PrayerSettings> {
  @override
  Future<PrayerSettings> build() =>
      ref.watch(prayerSettingsRepositoryProvider).load();
  Future<void> saveSettings(PrayerSettings next) async {
    state = AsyncData(next);
    await ref.read(prayerSettingsRepositoryProvider).save(next);
  }
}
