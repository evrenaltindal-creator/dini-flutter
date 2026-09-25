import 'dart:io';

import 'package:dini_flutter/app/router.dart';
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

import 'quran_fixture.dart';

/// Kullanıcı: "Kaza takibi aşağıdaki barın altına kaçıyor."
///
/// Sekme kabuğu `extendBody: true` ile çizilir: sayfa sekme çubuğunun
/// ARKASINA uzanır ki cami sahnesi çubuğun ardında da görünsün. Bu yüzden
/// her kaydırılan sayfa, en sonunda son satırı çubuğun üstüne çıkaracak
/// kadar alt boşluk bırakmalı. `ListView`'a elle `padding` verilince
/// Flutter çubuğun payını KENDİLİĞİNDEN eklemez; unutulunca listenin sonu
/// çubuğun altında kalır ve hiçbir kaydırmayla görünmez.
///
/// Test her sekme sayfasını sonuna kadar kaydırır ve hiçbir yazının sekme
/// çubuğunun altında kalmadığını denetler.
const screens = {
  '/': null,
  '/quran': null,
  '/calendar': null,
  '/calendar/month': null,
  '/settings': null,
  '/worship': 'Takip',
  '/worship ': 'Namaz',
  '/worship  ': 'Abdest',
  '/worship   ': 'Alarmlar',
};

late final String _citiesJson;
late final QuranBook _book;

void main() {
  setUpAll(() async {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
    _book = await loadQuranBookFromDisk();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final MapEntry(key: route, value: tab) in screens.entries) {
    final name = tab == null ? route : '${route.trim()} → $tab';
    testWidgets('$name: sonuna kadar kaydırınca yazı çubuğun altında kalmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Gerçek telefondaki alt güvenli alan (ana ekran çizgisi).
      tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(MemoryStorage()),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
            quranBookProvider.overrideWith((ref) => _book),
          ],
          child: DiniApp(router: createRouter(initialLocation: route.trim())),
        ),
      );
      await tester.pumpAndSettle();
      if (tab != null) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }

      final bar = tester.getRect(find.byType(NavigationBar));
      // Görünen dikey kaydırıcılar (sekme sayfalarından yalnız seçili olan).
      final scrollables = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
      );
      for (final element in scrollables.evaluate().toList()) {
        final state = (element as StatefulElement).state as ScrollableState;
        final box = element.renderObject as RenderBox?;
        if (box == null || !box.attached || !box.hasSize) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        // Ekranda olmayan (ör. seçilmemiş sekme) ya da çubuğa ulaşmayan
        // kaydırıcılar bu denetimin konusu değil.
        if (rect.width < 1 || rect.left >= 390 || rect.right <= 0) continue;
        if (rect.bottom <= bar.top) continue;
        // Tembel listelerde (ListView.builder) son satırlar kurulana kadar
        // "sonun" yeri tahmindir: son sabitlenene kadar tekrar atlanır.
        final position = state.position;
        for (var i = 0; i < 50; i++) {
          final end = position.maxScrollExtent;
          position.jumpTo(end);
          await tester.pumpAndSettle();
          if (position.maxScrollExtent == end) break;
        }

        final texts = find.descendant(
          of: find.byElementPredicate((e) => e == element),
          matching: find.byType(Text),
        );
        for (final text in texts.evaluate()) {
          final render = text.renderObject as RenderBox?;
          if (render == null || !render.attached || !render.hasSize) continue;
          final textRect = render.localToGlobal(Offset.zero) & render.size;
          if (textRect.left >= 390 || textRect.right <= 0) continue;
          if (textRect.top >= bar.top + 2) {
            final data = (text.widget as Text).data ?? '(zengin metin)';
            fail(
              '$name: "$data" sonuna kaydırılmış sayfada sekme çubuğunun '
              'altında kalıyor (yazının üstü ${textRect.top.round()}, çubuk '
              '${bar.top.round()}). Listenin alt boşluğuna '
              'MediaQuery.paddingOf(context).bottom eklenmeli.',
            );
          }
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
