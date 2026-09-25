import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/layout/readable_width.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backdrop_coverage_test.dart' show routes;
import 'quran_fixture.dart';

/// Kullanıcı: "şimdi bu app'i iPad için düzenle … sonra diğer şeyleri
/// kontrol et."
///
/// Her rota iPad'in dikey ve yatay boyutunda açılır: hiçbir sayfa taşma
/// hatası vermemeli ve kartlar okunur genişliği aşmamalı. Uygulama telefon
/// için tasarlandı; 1376 noktaya yayılan kartlar boş ve okunmaz kalıyordu.
late final String _citiesJson;
late final QuranBook _book;

const _sizes = {'dikey': Size(1032, 1376), 'yatay': Size(1376, 1032)};

void main() {
  setUpAll(() async {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
    _book = await loadQuranBookFromDisk();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final MapEntry(key: orientation, value: size) in _sizes.entries) {
    for (final route in routes) {
      testWidgets('iPad $orientation: $route', (tester) async {
        // Yalnız çizim yüzeyini değil ekranın kendisini büyüt: sayfalar
        // yerleşimi MediaQuery'den okur.
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageProvider.overrideWithValue(MemoryStorage()),
              cityRepositoryProvider.overrideWithValue(
                CityRepository(loadAsset: (_) async => _citiesJson),
              ),
              clockProvider.overrideWithValue(() => DateTime(2026, 9, 20, 12)),
              quranBookProvider.overrideWith((ref) => _book),
            ],
            child: DiniApp(router: createRouter(initialLocation: route)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route taşıyor.');

        for (final card in find.byType(Card).evaluate()) {
          final box = card.renderObject as RenderBox?;
          if (box == null || !box.hasSize) continue;
          expect(
            box.size.width,
            lessThanOrEqualTo(readableContentWidth),
            reason: '$route: kart ${box.size.width.round()} nokta genişliğinde',
          );
        }
      });
    }
  }
}
