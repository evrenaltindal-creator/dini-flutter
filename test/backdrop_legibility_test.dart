import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/prayer_times/presentation/settings_controller.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backdrop_coverage_test.dart' show routes;

/// Her sayfada, koyu cami perdesinin üstüne DOĞRUDAN düşen yazı açık renk
/// olmalı — hangi temada olursa olsun.
///
/// Sahne her temada koyudur. Kartın, çubuğun ya da renkli bir kutunun
/// içindeki yazı kendi zeminine göre renklenir ve burada ölçülmez; ölçülen,
/// arkasında perdeden başka bir şey olmayan yazıdır. İmsakiye ve takvim
/// bunun yüzünden okunmuyordu; sonra kullanıcı aynı şeyi Ayarlar'da gördü.
/// Sayfaları tek tek düzeltmek yerine bu test hepsini dolaşır.
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

/// Yazının arkasında perdeden başka bir zemin var mı?
bool _onSurface(Element element) {
  var surface = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Scaffold) return false; // perdeye ulaştık
    if (widget is Card) {
      surface = true;
    } else if (widget is Material &&
        widget.type != MaterialType.transparency &&
        (widget.color?.a ?? 0) > .5) {
      surface = true;
    } else if (widget is ColoredBox && widget.color.a > .5) {
      surface = true;
    } else if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && (decoration.color?.a ?? 0) > .5) {
        surface = true;
      }
    } else if (widget is NavigationBar || widget is AppBar) {
      // Kendi renkleri olan çubuklar; AppBar'ın yazı rengi açıkça beyaz.
      surface = true;
    }
    return !surface;
  });
  return surface;
}

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final route in routes) {
    testWidgets('$route: telefon aydınlık kipteyken de yazı okunur', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // En kötü durum: telefon aydınlık kipte. Uygulama sistemin kipini
      // izleseydi 17 sayfanın 12'sinde kart dışındaki yazı koyu-üstüne-koyu
      // çizilirdi.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      // Gerçek içerik görünsün: tercihler olmadan Ayarlar yalnızca hata
      // kartını çiziyor ve asıl denetlenmesi gereken kontroller hiç
      // ekrana gelmiyordu.
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localStorageProvider.overrideWithValue(_MemoryStorage()),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 20, 12)),
          ],
          child: DiniApp(router: createRouter(initialLocation: route)),
        ),
      );
      await tester.pumpAndSettle();

      final problems = <String>[];
      for (final element in find.byType(Text).evaluate()) {
        final text = element.widget as Text;
        final label = (text.data ?? text.textSpan?.toPlainText() ?? '').trim();
        if (label.isEmpty || _onSurface(element)) continue;
        final color = DefaultTextStyle.of(element).style
            .merge(text.style)
            .color;
        if (color == null || color.a < .05) continue;
        if (color.computeLuminance() < 0.4) {
          problems.add('"$label" ($color)');
        }
      }
      expect(
        problems,
        isEmpty,
        reason:
            '$route: bu yazılar kart dışında, koyu perdenin üstünde koyu '
            'renkle çiziliyor:\n${problems.join('\n')}',
      );
    });
  }
}
