import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_provider.dart';

final widgetLocationVisibilityProvider = FutureProvider<bool>(
  (ref) =>
      WidgetPreferencesRepository(ref.watch(localStorageProvider))
          .showLocationName(),
);

class WidgetPreferencesRepository {
  final LocalStorage storage;
  const WidgetPreferencesRepository(this.storage);
  static const showLocationKey = 'dini.widget.showLocation';
  Future<bool> showLocationName() async =>
      (await storage.read(showLocationKey) ?? '0') == '1';
  Future<void> setShowLocationName(bool value) async =>
      storage.write(showLocationKey, value ? '1' : '0');
}
