import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

late final String _citiesJson;

/// Uygulamanın arka planını gösteren her rota.
///
/// Kabuğun içindeki sekmeler ve tek tek açılan sayfalar birlikte.
const routes = [
  '/',
  '/quran',
  '/quran/page/42',
  '/quran/surah/2',
  '/worship',
  '/calendar',
  '/calendar/month',
  '/settings',
  '/privacy',
  '/about',
  '/qibla',
  '/location',
  '/onboarding',
  '/teravih',
  '/fasting',
  '/imsakiye',
  '/tasbih',
  '/tracker',
  '/notifications',
  '/guide/prayer/dhuhr',
  '/leaf/2026-09-22',
  '/guide/prayer/fajr/hoca',
  '/guide/prayer/isha/hoca?part=3',
];

Widget _app(String location) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(_MemoryStorage()),
    cityRepositoryProvider.overrideWithValue(
      CityRepository(loadAsset: (_) async => _citiesJson),
    ),
    clockProvider.overrideWithValue(() => DateTime(2026, 9, 20, 12)),
  ],
  child: DiniApp(router: createRouter(initialLocation: location)),
);

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cami arka planı her sayfada görünür', () {
    for (final route in routes) {
      testWidgets('$route sayfasında sahne örtülmez', (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_app(route));
        await tester.pumpAndSettle();

        expect(
          find.byType(MosqueScene),
          findsOneWidget,
          reason: '$route sahneyi hiç çizmiyor.',
        );

        // Temanın zemin rengi OPAKTIR. Saydam yapılmayan bir Scaffold
        // sahnenin üstünü tamamen boyar: sayfa açılır, cami kaybolur.
        final opaque = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .where((scaffold) => scaffold.backgroundColor != Colors.transparent)
            .toList();
        expect(
          opaque,
          isEmpty,
          reason:
              '$route sayfasındaki Scaffold saydam değil; arka plandaki cami '
              'örtülüyor. BackdropScaffold kullanın ya da '
              'backgroundColor: Colors.transparent verin.',
        );
      });
    }
  });
}
