import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/presentation/daily_leaf_page.dart';
import 'package:dini_flutter/features/home/presentation/mosque_backdrop.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Günün takvim yaprağı (kullanıcı isteği: duvar takvimi gibi).
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
    clockProvider.overrideWithValue(() => DateTime(2026, 9, 22, 12)),
  ],
  child: DiniApp(router: createRouter(initialLocation: location)),
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Yazının hemen arkasındaki boyalı zemin.
Color _background(Element element) {
  Color? color;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is ColoredBox) color = widget.color;
    if (widget is Card) color = widget.color;
    return color == null;
  });
  return color!;
}

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, String location) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(location));
    await tester.pumpAndSettle();
  }

  group('yol', () {
    test('tarih gidip gelir, geçersiz tarih reddedilir', () {
      final date = DateTime(2026, 9, 22);
      final path = DailyLeafPage.routeFor(date);
      expect(path, '/leaf/2026-09-22');
      expect(DailyLeafPage.parse(path.split('/').last), date);
      // DateTime 31 Şubat'ı sessizce 3 Mart'a çevirirdi.
      expect(DailyLeafPage.parse('2026-02-31'), isNull);
      expect(DailyLeafPage.parse('dün'), isNull);
    });
  });

  testWidgets('yaprak günün bilgilerini taşır', (tester) async {
    await open(tester, '/leaf/2026-09-22');
    final paper = find.byKey(DailyLeafPage.paperKey);
    Finder onPaper(String text) =>
        find.descendant(of: paper, matching: find.textContaining(text));

    expect(onPaper('Eylül 2026'), findsOneWidget);
    expect(onPaper('22'), findsWidgets);
    expect(onPaper('Salı'), findsOneWidget);
    // Rumi: 22 Eylül 2026 Jülyen'de 9 Eylül'dür; yıl 2026 - 584.
    expect(onPaper('9 Eylül 1442'), findsOneWidget);
    // Hıdrellez'den (6 Mayıs) bu yana 140. gün; yılın 265. günü.
    expect(onPaper('Hızır 140'), findsOneWidget);
    expect(onPaper('Yılın 265. günü · 100 gün kaldı'), findsOneWidget);
    // Hicri ay adıyla yazılır, sayıyla değil.
    expect(onPaper('Rebiülahir'), findsOneWidget);
    expect(onPaper('İmsak'), findsOneWidget);
  });

  testWidgets('yaprak çevrilir', (tester) async {
    await open(tester, '/leaf/2026-09-22');
    await tester.tap(find.byTooltip('Sonraki gün').first);
    await tester.pumpAndSettle();
    expect(find.text('Çarşamba'), findsOneWidget);
    await tester.tap(find.byTooltip('Önceki gün').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Önceki gün').first);
    await tester.pumpAndSettle();
    expect(find.text('Pazartesi'), findsOneWidget);
  });

  testWidgets('Cuma kırmızı basılır', (tester) async {
    await open(tester, '/leaf/2026-09-25');
    final day = tester.widget<Text>(
      find.descendant(
        of: find.byKey(DailyLeafPage.paperKey),
        matching: find.text('25'),
      ),
    );
    expect(day.style?.color, leafRed);
  });

  testWidgets('kâğıttaki her yazı okunur', (tester) async {
    // Uygulama koyu temayla çizilir; kartın varsayılan yazısı açık renktir
    // ve krem kâğıtta okunmazdı. Her yazı arkasındaki zemine karşı ölçülür.
    await open(tester, '/leaf/2026-09-22');
    final texts = find
        .descendant(
          of: find.byKey(DailyLeafPage.paperKey),
          matching: find.byType(Text),
        )
        .evaluate();
    expect(texts, isNotEmpty);
    for (final element in texts) {
      final text = element.widget as Text;
      final color = DefaultTextStyle.of(element).style.merge(text.style).color!;
      expect(
        _contrast(color, _background(element)),
        greaterThanOrEqualTo(4.5),
        reason: '"${text.data}" zeminine karşı okunmuyor ($color).',
      );
    }
  });

  for (final language in ['tr', 'en', 'ar']) {
    testWidgets('$language: dar ekranda taşmaz', (tester) async {
      // Taşma, testte bir hata olarak yakalanır.
      await tester.binding.setSurfaceSize(const Size(320, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(_MemoryStorage()),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 22, 12)),
            localeProvider.overrideWith((ref) => Locale(language)),
          ],
          child: DiniApp(router: createRouter(initialLocation: '/leaf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(DailyLeafPage.paperKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('takvimden seçilen günün yaprağı açılır', (tester) async {
    await open(tester, '/calendar/month');
    await tester.ensureVisible(find.text('Takvim yaprağını aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Takvim yaprağını aç'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyLeafPage), findsOneWidget);
  });

  testWidgets('takvim sekmesi önce yaprağı açar, geçişle ay gelir', (
    tester,
  ) async {
    // Kullanıcı isteği: "takvim bölümünde ilk önce yaprak tarafı gelsin".
    await open(tester, '/calendar');
    expect(find.byKey(DailyLeafPage.paperKey), findsOneWidget);
    expect(find.byType(CalendarModeSwitch), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    await tester.tap(find.text('Aylık takvim'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byKey(DailyLeafPage.paperKey), findsNothing);

    await tester.tap(find.text('Günün yaprağı'));
    await tester.pumpAndSettle();
    expect(find.byKey(DailyLeafPage.paperKey), findsOneWidget);
  });

  testWidgets('sekmedeki yaprak ikinci bir cami perdesi çizmez', (
    tester,
  ) async {
    // Sekme kabuğu perdeyi zaten çiziyor; ikincisi sahneyi koyulaştırırdı.
    await open(tester, '/calendar');
    expect(find.byType(MosqueBackdrop), findsOneWidget);
    expect(find.byType(BackdropScaffold), findsNothing);
  });
}
