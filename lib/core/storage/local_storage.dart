import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesStorage implements LocalStorage {
  final SharedPreferences prefs;
  SharedPreferencesStorage(this.prefs);
  @override
  Future<String?> read(String key) async => prefs.getString(key);
  @override
  Future<void> write(String key, String value) async =>
      prefs.setString(key, value);
  @override
  Future<void> remove(String key) async => prefs.remove(key);
}
