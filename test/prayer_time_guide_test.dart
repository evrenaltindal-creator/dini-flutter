import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/worship/presentation/prayer_guide_view.dart';
import 'package:dini_flutter/features/worship/presentation/worship_hub_page.dart';
import 'package:dini_flutter/main.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana ekrandaki "Bugünün vakitleri" satırına dokununca o namazın nasıl
/// kılındığı açılır (kullanıcı isteği).
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

  Future<void> open(WidgetTester tester, String location) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(location));
    await tester.pumpAndSettle();
  }

  for (final (prayer, label) in [
    (Prayer.fajr, 'Sabah'),
    (Prayer.dhuhr, 'Öğle'),
    (Prayer.isha, 'Yatsı'),
  ]) {
    testWidgets('$label satırı $label namazının rehberini açar', (
      tester,
    ) async {
      await open(tester, '/');
      await tester.tap(find.byTooltip('$label namazı nasıl kılınır'));
      await tester.pumpAndSettle();

      final page = tester.widget<PrayerGuideDetailPage>(
        find.byType(PrayerGuideDetailPage),
      );
      expect(page.guide.prayer, prayer);
    });
  }

  testWidgets('güneş doğuşu satırı rehber açmaz', (tester) async {
    // Güneş doğuşu namaz vakti değildir; rehberi yoktur.
    await open(tester, '/');
    expect(find.byTooltip('Güneş doğuşu namazı nasıl kılınır'), findsNothing);
    await tester.tap(find.textContaining('Güneş doğuşu'));
    await tester.pumpAndSettle();
    expect(find.byType(PrayerGuideDetailPage), findsNothing);
  });

  testWidgets('bilinmeyen vakit adı yanlış rehber açmaz', (tester) async {
    await open(tester, '/guide/prayer/sunrise');
    expect(find.byType(PrayerGuideDetailPage), findsNothing);
    expect(find.byType(WorshipHubPage), findsOneWidget);
  });

  test('her namazın yolu kendi rehberine çözülür', () {
    for (final prayer in [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]) {
      final path = PrayerGuideDetailPage.routeFor(prayer);
      final name = path.split('/').last;
      expect(PrayerGuideDetailPage.guideFor(name)?.prayer, prayer);
    }
  });
}
