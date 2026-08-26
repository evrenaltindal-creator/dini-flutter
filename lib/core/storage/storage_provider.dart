import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_storage.dart';
import '../../features/prayer_times/presentation/settings_controller.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  try {
    return SharedPreferencesStorage(ref.watch(sharedPreferencesProvider));
  } on StateError {
    return MemoryStorage();
  }
});

class MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}
