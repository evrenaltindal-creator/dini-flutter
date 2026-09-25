import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/qibla/presentation/qibla_page.dart';
import 'package:dini_flutter/features/tasbih/presentation/tasbih_page.dart';
import 'package:dini_flutter/features/widgets/data/widget_snapshot_builder.dart';
import 'package:dini_flutter/features/worship/presentation/worship_hub_page.dart';
import 'package:dini_flutter/main.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı: "widget'ta konumu gösterme, onun yerine tesbih, kıble ve
/// takip düğmeleri olsun. Basınca kısayol gibi hemen app açılsın, o sekmeye
/// gitsin." Ayrıca: sıradaki namaza ne kadar kaldığı görünsün; vakitler
/// üstte üç, altta iki, ortalı.
late final String _citiesJson;
late final String _widget;
late final String _plist;

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
    _widget = File('ios/DiniWidget/DiniWidget.swift').readAsStringSync();
    _plist = File('ios/Runner/Info.plist').readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Widget'taki düğmelerin rotaları, Swift kaynağından.
  List<String> shortcutRoutes() => [
    for (final match in RegExp(
      r'shortcut\([^)]*route: "([a-z/]+)"\)',
    ).allMatches(_widget))
      match.group(1)!,
  ];

  group('widget kaynağı', () {
    test('üç kısayol var: tesbih, kıble, takip', () {
      expect(shortcutRoutes(), ['tasbih', 'qibla', 'tracker']);
    });

    test('adres şeması uygulamada tanımlı', () {
      // Şema Info.plist'te yoksa düğmeye basınca hiçbir şey olmaz.
      final scheme = RegExp(r'static let scheme = "([a-z]+)"')
          .firstMatch(_widget)
          ?.group(1);
      expect(scheme, 'namazyolu');
      expect(_plist, contains('<string>$scheme</string>'));
      expect(_plist, contains('CFBundleURLSchemes'));
      // Flutter adresi yönlendiriciye yalnız bu açıksa verir.
      expect(
        RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<true/>')
            .hasMatch(_plist),
        isTrue,
      );
    });

    test('konum gösterilmez, kalan süre gösterilir', () {
      expect(_widget, isNot(contains('locationName')));
      expect(_widget, contains('style: .timer'));
    });

    test('vakitler üstte üç, altta iki', () {
      expect(_widget, contains('entry.prayers.prefix(3)'));
      expect(_widget, contains('entry.prayers.suffix(from: 3)'));
    });

    test('sıradaki vakit yatsıdan sonra yarının sabahına geçer', () {
      // Uygulama açılmasa da widget sıradaki vakti kendisi seçmeli.
      expect(_widget, contains('"tomorrowFajr"'));
    });
  });

  group('anlık görüntü', () {
    test('yarının sabah vakti ve düğme adları üç dilde gider', () {
      for (final code in ['tr', 'en', 'ar']) {
        final json = buildWidgetSnapshot(
          settings: const PrayerSettings(),
          now: DateTime.utc(2026, 9, 25, 19), // İstanbul'da yatsıdan sonra
          languageCode: code,
        ).toJson(showLocationName: false);
        final l10n = AppLocalizations(Locale(code));
        expect(json['label_tasbih'], l10n.text('home.tasbih'), reason: code);
        expect(json['label_qibla'], l10n.text('home.qibla'), reason: code);
        expect(json['label_tracker'], l10n.text('worship.tracker'));
        expect(json['label_remaining'], l10n.text('widget.remaining'));

        final fajr = DateTime.parse(json['fajr'] as String);
        final tomorrow = DateTime.parse(json['tomorrowFajr'] as String);
        final gap = tomorrow.difference(fajr);
        // Ertesi günün kendi hesabı: yaklaşık bir gün sonra, ama aynı dakika
        // olmak zorunda değil.
        expect(gap.inHours, inInclusiveRange(23, 25), reason: code);
      }
    });

    test('yarının sabahı yatsıdan sonra sıradaki vakittir', () {
      final snapshot = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 25, 19),
        languageCode: 'tr',
      );
      expect(snapshot.nextPrayer, Prayer.fajr);
      expect(
        snapshot.tomorrowFajr!.isAfter(snapshot.prayers[Prayer.isha]!),
        isTrue,
      );
    });
  });

  group('kısayol adresi uygulamayı o bölümde açar', () {
    Future<void> openLink(WidgetTester tester, String route) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(MemoryStorage()),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          ],
          child: DiniApp(router: createRouter()),
        ),
      );
      await tester.pumpAndSettle();
      // iOS'un Flutter'a gönderdiği mesajın aynısı (FlutterEngine
      // sendDeepLinkToFramework: tam adres, "location" olarak).
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {
            'location': 'namazyolu://open/$route',
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    final expected = <String, Type>{
      'tasbih': TasbihPage,
      'qibla': QiblaPage,
      'tracker': WorshipHubPage,
    };

    test('her düğmenin beklenen bir sayfası var', () {
      expect(shortcutRoutes().toSet(), expected.keys.toSet());
    });

    for (final MapEntry(key: route, value: page) in expected.entries) {
      testWidgets('namazyolu://open/$route → $page', (tester) async {
        await openLink(tester, route);
        expect(find.byType(page), findsOneWidget);
        if (route == 'tracker') {
          // Takip sekmesi seçili açılır.
          final tabs = DefaultTabController.of(
            tester.element(find.byType(TabBarView)),
          );
          expect(tabs.index, 0);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
