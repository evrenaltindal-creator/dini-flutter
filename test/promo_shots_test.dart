@Tags(['promo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements LocalStorage {
  _MemoryStorage(this.values);
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

late final String _citiesJson;

Future<void> _register(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      File(path).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  const cache = '/tmp/flutter/bin/cache/artifacts/material_fonts';
  const dejavu = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  await _register('Roboto', [
    '$cache/Roboto-Regular.ttf',
    '$cache/Roboto-Medium.ttf',
    '$cache/Roboto-Bold.ttf',
    dejavu,
  ]);
  await _register('MaterialIcons', ['$cache/MaterialIcons-Regular.otf']);
}

/// Sürekli dönen animasyonlu ekranlarda `pumpAndSettle` hiç durmaz; kare
/// sayısı sınırlı bir bekleme yeter.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }
}

void main() {
  setUpAll(() async {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
    await _loadFonts();
  });

  /// Pusula olayını taklit eder; aksi hâlde kıble ekranı "sensör
  /// kullanılamıyor" uyarısını gösterir ve tanıtım görseli yanlış anlatır.
  void fakeCompass(double heading) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('hemanthraj/flutter_compass'),
          MockStreamHandler.inline(
            onListen: (arguments, sink) {
              sink.success(<double>[heading, heading, 1]);
            },
          ),
        );
  }

  Future<void> shoot(
    WidgetTester tester,
    String route,
    String name, {
    DateTime? now,
    Map<String, String>? seed,
    double? heading,
  }) async {
    if (heading != null) fakeCompass(heading);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(
              _MemoryStorage(seed ?? <String, String>{}),
            ),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(
              () => now ?? DateTime(2026, 9, 20, 17, 42),
            ),
          ],
          child: DiniApp(router: createRouter(initialLocation: route)),
        ),
      ),
    );
    await _settle(tester);
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        // Bir görsel çözülemezse (test ortamında olur) kare beklemeye devam
        // etmek suiti asıyor; süre sınırı koy.
        await precacheImage(
          image.image,
          element,
        ).timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    });
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final out = File('build/promo_shots/$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  // Ramazan gecesi (mahya) ekranı bilerek yok: mahyanın yazısı adı
  // verilmemiş bir yazı tipiyle çiziliyor, test ortamı da böyle metni dolu
  // kutu olarak basıyor. O görüntü gerçek cihazdan alınmalı.

  // Namaz takibi ekranı boşken anlatmıyor; son kırk gün işaretli geliyor.
  // Anahtar biçimi depodan alındı: dini.tracker.<YYYY-AA-GG>.<vakit> = '1'.
  final tracked = <String, String>{};
  for (var back = 0; back < 40; back++) {
    final day = DateTime(2026, 9, 20 - back);
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      // Arada bir eksik gün; ısı haritası tekdüze bir blok gibi durmasın.
      if (back % 9 == 4 && prayer == 'isha') continue;
      tracked['dini.tracker.$key.$prayer'] = '1';
    }
  }

  final screens =
      <
        String,
        ({
          String route,
          DateTime? now,
          double? heading,
          Map<String, String>? seed,
        })
      >{
        'home': (route: '/', now: null, heading: null, seed: null),
        'qibla': (route: '/qibla', now: null, heading: 142.0, seed: null),
        'imsakiye': (route: '/imsakiye', now: null, heading: null, seed: null),
        'tracker': (route: '/tracker', now: null, heading: null, seed: tracked),
        'worship': (route: '/worship', now: null, heading: null, seed: null),
        'calendar': (
          route: '/calendar/month',
          now: null,
          heading: null,
          seed: null,
        ),
        'tasbih': (route: '/tasbih', now: null, heading: null, seed: null),
        'leaf': (
          route: '/leaf/2026-09-25',
          now: null,
          heading: null,
          seed: null,
        ),
      };

  screens.forEach((name, screen) {
    testWidgets(name, (tester) async {
      await shoot(
        tester,
        screen.route,
        name,
        now: screen.now,
        heading: screen.heading,
        seed: screen.seed,
      );
    });
  });
}
