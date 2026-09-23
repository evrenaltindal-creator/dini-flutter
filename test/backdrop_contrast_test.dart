import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/presentation/calendar_page.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/imsakiye_page.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cami perdesinin üstüne doğrudan yazılan metin her temada AÇIK renk olmalı.
///
/// Bu ekranlar `BackdropScaffold` ile saydam yapıldığında arkalarında koyu
/// bir fotoğraf ve onu daha da karartan bir perde kaldı; ama yazı renkleri
/// temadan geliyordu. Cihaz aydınlık kipteyken (varsayılan) imsakiye
/// çizelgesi ve takvim ızgarası koyu yazıyla koyu zemine düşüyor, ekran
/// neredeyse boş görünüyordu. Ekran görüntüsü alınırken fark edildi.
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

/// Metnin çözülmüş rengi; stil yoksa temanın varsayılanı.
Color _colorOf(WidgetTester tester, Text text) {
  final style = text.style;
  if (style?.color != null) return style!.color!;
  final context = tester.element(find.byWidget(text));
  final fallback = DefaultTextStyle.of(context).style.color;
  return fallback ?? const Color(0xFF000000);
}

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Perdenin üstündeki metni toplar ve hepsinin açık renk olduğunu bekler.
  Future<void> expectLightText(
    WidgetTester tester, {
    required String route,
    required Brightness platform,
    required Finder area,
    required Finder excluded,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(_app(route));
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(
          find.descendant(of: area, matching: find.byType(Text)),
        )
        .where((text) => (text.data ?? '').trim().isNotEmpty)
        .toList();
    // Bugünün satırı/hücresi açık renk bir kutunun içindedir; onun yazısı
    // bilerek koyudur ve ölçümün dışında kalır.
    final exempt = tester
        .widgetList<Text>(
          find.descendant(of: excluded, matching: find.byType(Text)),
        )
        .toSet();
    texts.removeWhere(exempt.contains);

    expect(
      texts,
      isNotEmpty,
      reason: '$route ekranında ölçülecek metin bulunamadı.',
    );
    for (final text in texts) {
      final color = _colorOf(tester, text);
      expect(
        color.computeLuminance(),
        greaterThan(0.4),
        reason:
            '$route ekranında "${text.data}" koyu renkle ($color) çiziliyor; '
            'arkasında koyu cami perdesi var, okunmaz.',
      );
    }
  }

  for (final platform in Brightness.values) {
    final name = platform == Brightness.light ? 'aydınlık' : 'koyu';

    testWidgets('$name kipte imsakiye çizelgesi okunur', (tester) async {
      await expectLightText(
        tester,
        route: '/imsakiye',
        platform: platform,
        area: find.byType(ListView),
        excluded: find.byKey(ImsakiyePage.todayRowKey),
      );
    });

    testWidgets('$name kipte takvim ızgarası okunur', (tester) async {
      await expectLightText(
        tester,
        route: '/calendar/month',
        platform: platform,
        area: find.byType(GridView),
        excluded: find.byKey(CalendarPage.selectedDayKey),
      );
    });
  }
}
