import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/home/presentation/mosque_backdrop.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {String languageCode = 'tr'}) => ProviderScope(
  child: MaterialApp(
    locale: Locale(languageCode),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

void main() {
  setUpAll(TimezoneService.initialize);

  group('sahne bir kez çizilir', () {
    testWidgets('tek başına kullanıldığında sahne vardır', (tester) async {
      await tester.pumpWidget(
        _app(const MosqueBackdrop(child: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MosqueScene), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iç içe kullanıldığında ikinci sahne çizilmez', (tester) async {
      // Ayarlar gibi sayfalar hem kabuğun içinde hem de doğrudan açılabilir.
      // İki sahne çizilseydi giriş animasyonu iki kez oynar ve iki perde üst
      // üste binerek ekranı olduğundan koyu gösterirdi.
      await tester.pumpWidget(
        _app(
          const MosqueBackdrop(child: MosqueBackdrop(child: SizedBox.shrink())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(MosqueScene),
        findsOneWidget,
        reason: 'İç içe arka plan sahneyi iki kez çiziyor.',
      );
    });

    testWidgets('üç kat iç içe olsa bile tek sahne kalır', (tester) async {
      await tester.pumpWidget(
        _app(
          const MosqueBackdrop(
            child: MosqueBackdrop(
              child: MosqueBackdrop(child: SizedBox.shrink()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MosqueScene), findsOneWidget);
    });
  });

  group('BackdropScaffold', () {
    testWidgets('iskelet saydamdır, yoksa sahne tamamen örtülür', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const BackdropScaffold(title: 'Başlık', body: Text('içerik'))),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        Colors.transparent,
        reason: 'Opak bir Scaffold arkadaki sahneyi tamamen kapatır.',
      );
      expect(find.text('Başlık'), findsOneWidget);
      expect(find.text('içerik'), findsOneWidget);
    });

    testWidgets('üst çubuk da saydamdır', (tester) async {
      await tester.pumpWidget(
        _app(const BackdropScaffold(title: 'Başlık', body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(
        appBar.foregroundColor,
        Colors.white,
        reason: 'Koyu fotoğrafın üzerinde koyu başlık okunmaz.',
      );
    });

    testWidgets('başlık verilmezse üst çubuk çizilmez', (tester) async {
      await tester.pumpWidget(
        _app(const BackdropScaffold(body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('perde', () {
    testWidgets('yoğun ekranların perdesi ana ekrandan koyudur', (
      tester,
    ) async {
      // Tabloyu ya da uzun bir listeyi fotoğrafın üzerine ince bir perdeyle
      // koymak okunmaz bir ekran demektir.
      Future<List<Color>> colorsFor(BackdropScrim scrim) async {
        await tester.pumpWidget(
          _app(MosqueBackdrop(scrim: scrim, child: const SizedBox.shrink())),
        );
        await tester.pump(const Duration(milliseconds: 400));
        // Sahnenin kendi içinde de degrade var; perde anahtarla bulunur.
        final box = tester.widget<DecoratedBox>(
          find.byKey(MosqueBackdrop.scrimKey),
        );
        final gradient =
            (box.decoration as BoxDecoration).gradient! as LinearGradient;
        return gradient.colors;
      }

      final light = await colorsFor(BackdropScrim.light);
      final heavy = await colorsFor(BackdropScrim.heavy);

      // Opaklık ortalaması: koyu perde belirgin biçimde daha örtücü olmalı.
      double opacity(List<Color> colors) =>
          colors.map((c) => c.a).reduce((a, b) => a + b) / colors.length;

      expect(
        opacity(heavy),
        greaterThan(opacity(light) + 0.4),
        reason:
            'Yoğun ekranların perdesi metni okunur kılacak kadar koyu değil: '
            'hafif ${opacity(light)}, koyu ${opacity(heavy)}.',
      );
    });
  });

  group('üç dilde ve dar ekranda', () {
    for (final language in ['tr', 'en', 'ar']) {
      for (final width in [320.0, 430.0]) {
        testWidgets('${width.toInt()}dp $language dilinde hatasız çizilir', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            _app(
              const BackdropScaffold(
                title: 'Başlık',
                body: Center(child: Text('içerik')),
              ),
              languageCode: language,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Arapça sağdan sola kalır', (tester) async {
      await tester.pumpWidget(
        _app(
          const BackdropScaffold(title: 'عنوان', body: SizedBox.shrink()),
          languageCode: 'ar',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        Directionality.of(tester.element(find.byType(BackdropScaffold))),
        TextDirection.rtl,
      );
    });
  });
}
