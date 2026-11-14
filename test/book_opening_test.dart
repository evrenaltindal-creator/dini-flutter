import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/quran/presentation/book_opening.dart';
import 'package:dini_flutter/features/quran/presentation/quran_reader_page.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';

import 'quran_fixture.dart';

import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı isteği: "Kuran simgesine basınca bir kitap açılıyormuş gibi
/// olsun."
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
late final QuranBook book;

void main() {
  setUpAll(() async {
    book = await loadQuranBookFromDisk();
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester,
    String location, {
    bool reduceMotion = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(_MemoryStorage()),
          quranBookProvider.overrideWith((ref) => book),
          cityRepositoryProvider.overrideWithValue(
            CityRepository(loadAsset: (_) async => _citiesJson),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 23, 12)),
        ],
        child: DiniApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pump();
  }

  final cover = find.byKey(BookOpening.coverKey);

  testWidgets('Kur’an sayfaları kapak veya liste bekletmeden açılır', (
    tester,
  ) async {
    await open(tester, '/quran');
    await tester.pumpAndSettle();
    expect(cover, findsNothing);
    expect(find.byType(QuranReaderPage), findsOneWidget);
    expect(find.text('Fâtiha · Sayfa 1'), findsOneWidget);
  });
  testWidgets('hareketi azalt açıkken de sayfalar doğrudan açılır', (
    tester,
  ) async {
    await open(tester, '/quran', reduceMotion: true);
    await tester.pumpAndSettle();
    expect(cover, findsNothing);
    expect(find.byType(QuranReaderPage), findsOneWidget);
  });
  testWidgets('sekmeler arasında okuyucu konumu korunur', (tester) async {
    await open(tester, '/quran/page/42');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuran'));
    await tester.pumpAndSettle();
    expect(cover, findsNothing);
    expect(find.text('Bakara · Sayfa 42'), findsOneWidget);
  });
}
