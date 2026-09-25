import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';
import 'package:dini_flutter/features/quran/data/quran_meta.dart';
import 'package:dini_flutter/features/quran/data/surah_names.dart';
import 'package:dini_flutter/features/quran/presentation/mushaf_page.dart';
import 'package:dini_flutter/features/quran/presentation/quran_meal_page.dart';
import 'package:dini_flutter/features/quran/presentation/quran_reader_page.dart';
import 'package:dini_flutter/features/quran/presentation/translator_about.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_fixture.dart';

late final QuranBook book;
late final String _citiesJson;

void main() {
  setUpAll(() async {
    // Sığdırma gerçek yazı tipiyle ölçülmeli: testin varsayılan yazı tipi
    // her harfi tam kare çizer ve Arapça satırlar olduğundan çok uzar.
    for (final (family, path) in [
      ('AmiriQuran', 'assets/fonts/AmiriQuran-Regular.ttf'),
      ('Amiri', 'assets/fonts/Amiri-Bold.ttf'),
    ]) {
      final bytes = File(path).readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
    book = await loadQuranBookFromDisk();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Medine Mushaf sayfaları', () {
    QuranMeta meta() => book.meta;

    test('604 sayfa; her âyet tam bir sayfada, sırayla', () {
      var next = 0;
      for (var page = 1; page <= QuranMeta.pageCount; page++) {
        for (final segment in meta().segmentsOf(page)) {
          final start = meta().indexOf(AyahRef(segment.surah, 1));
          expect(start + segment.firstAyah - 1, next, reason: 'sayfa $page');
          next = start + segment.lastAyah;
        }
      }
      expect(next, 6236);
    });

    test('basılı Mushaf’la aynı yerler', () {
      // Fâtiha tek başına 1. sayfada, Bakara 2. sayfada başlar.
      expect(meta().segmentsOf(1).single.lastAyah, 7);
      expect(meta().segmentsOf(2).single.surah, 2);
      expect(meta().segmentsOf(2).single.startsSurah, isTrue);
      expect(meta().firstPageOfSurah(18), 293); // Kehf
      expect(meta().firstPageOfSurah(36), 440); // Yâsîn
      expect(meta().firstPageOfSurah(67), 562); // Mülk
      expect(meta().firstPageOfJuz(30), 582); // Amme cüzü
      // Son sayfada İhlâs, Felak ve Nâs.
      expect(meta().segmentsOf(604).map((s) => s.surah), [112, 113, 114]);
      expect(meta().pageOf(const AyahRef(2, 255)), 42); // Âyetü'l-Kürsî
    });

    test('cüzler', () {
      expect(meta().juzOfPage(1), 1);
      expect(meta().juzOfPage(22), 2);
      expect(meta().juzOfPage(604), 30);
      for (var juz = 1; juz <= 30; juz++) {
        expect(meta().juzOfPage(meta().firstPageOfJuz(juz)), juz);
      }
    });
  });

  group('sûre adları', () {
    test('114 Türkçe ad, her biri bir kez', () {
      expect(turkishSurahNames, hasLength(114));
      expect(turkishSurahNames.toSet(), hasLength(114));
      expect(book.surahName(1, 'tr'), 'Fâtiha');
      expect(book.surahName(36, 'tr'), 'Yâsîn');
      expect(book.surahName(112, 'tr'), 'İhlâs');
      expect(book.surahName(114, 'tr'), 'Nâs');
    });

    test('İngilizce ve Arapça adlar Tanzil’den gelir', () {
      expect(book.surahName(2, 'en'), 'Al-Baqara');
      expect(book.surahName(2, 'ar'), 'البقرة');
    });
  });

  group('mealler', () {
    test('her meal tam, kaynağı Hakkında sayfasında üç dilde', () {
      for (final MapEntry(key: language, value: id)
          in quranTranslations.entries) {
        final translation = book.translationFor(language)!;
        expect(translation.surahs, hasLength(114), reason: id);
        // Kaynak notundaki kaynak Hakkında sayfasında da yazmalı.
        final domain = {
          'en.pickthall': 'tanzil.net',
          'tr.elmalili': 'namazzamani.net',
        }[id];
        expect(domain, isNotNull, reason: '$id için kaynak tanımlı değil');
        for (final code in ['tr', 'en', 'ar']) {
          expect(
            AppLocalizations(Locale(code)).text('quran.source.$id'),
            contains(domain),
            reason: '$id, $code',
          );
        }
      }
      expect(
        book.translationFor('en')!.ayah(1, 2),
        'Praise be to Allah, Lord of the Worlds,',
      );
    });

    test('Türkçe meal Elmalılı\'nın 1935 aslıdır, sadeleştirilmiş değil', () {
      // Tanzil'in tr.yazir dosyası sonradan sadeleştirilmiş, ayrıca telifli
      // bir baskıdır: Âyetü'l-Kürsî orada "Allah'tan başka hiçbir ilâh
      // yoktur. O daima diridir (hayydır)…" diye başlar. Aslı:
      final turkish = book.translationFor('tr')!;
      expect(
        turkish.ayah(2, 255),
        startsWith('Allah, başka tanrı yok ancak o, daima yaşıyan'),
      );
      expect(turkish.ayah(2, 255), isNot(contains('(hayydır)')));
      expect(turkish.ayah(1, 5), startsWith('Sade sana ederiz kulluğu'));
      expect(turkish.ayah(112, 1), 'De, o: Allah tek bir (ehad)dir');
    });

    test('Elmalılı hakkındaki yazı kaynağa dayanır', () {
      for (final code in ['tr', 'en', 'ar']) {
        final l10n = AppLocalizations(Locale(code));
        final body = l10n.text('quran.translatorAbout.tr.elmalili.body');
        // Ödenek TBMM'nin 21 Şubat 1925 kararıyla Diyanet bütçesinden
        // verildi; "Atatürk kendi cebinden ödedi" yaygın ama yanlıştır.
        expect(body, contains('1925'), reason: code);
        expect(body, contains('1942'), reason: code);
        expect(body, isNot(contains('cebinden')), reason: code);
        expect(body, isNot(contains('own pocket')), reason: code);
        expect(
          l10n.text('quran.translatorAbout.tr.elmalili.sources'),
          contains('Türk Maarif Tarihi'),
          reason: code,
        );
      }
      // Hakkında yazısı olan her mütercimin üç parçası da var.
      for (final id in translatorsWithAbout) {
        for (final part in ['title', 'body', 'sources']) {
          final key = 'quran.translatorAbout.$id.$part';
          expect(AppLocalizations(const Locale('tr')).text(key), isNot(key));
        }
      }
    });

    test('birlikte çevrilen âyet çiftleri tanınır', () {
      final turkish = book.translationFor('tr')!;
      // "(168-169) …" iki âyette de aynı metin.
      expect(translatedWithPrevious(turkish, 4, 169), isTrue);
      expect(translatedWithPrevious(turkish, 4, 168), isFalse);
      expect(translatedWithPrevious(turkish, 81, 9), isTrue);
      expect(translatedWithPrevious(turkish, 1, 2), isFalse);
      var pairs = 0;
      for (var surah = 1; surah <= 114; surah++) {
        for (var ayah = 1; ayah <= turkish.ayahsIn(surah); ayah++) {
          if (translatedWithPrevious(turkish, surah, ayah)) pairs++;
        }
      }
      expect(pairs, 19);
      expect(
        translatedWithPrevious(book.translationFor('en')!, 4, 169),
        isFalse,
      );
    });

    test('Arapça okuyana meal yok', () {
      expect(book.translationFor('ar'), isNull);
    });
  });

  group('ekranlar', () {
    Future<MemoryStorage> open(
      WidgetTester tester,
      String location, {
      String language = 'tr',
      Map<String, String> saved = const {},
      Size size = const Size(390, 844),
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Kitap açılışı ayrıca test ediliyor; burada beklemesin.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final storage = MemoryStorage()..values.addAll(saved);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
            localeProvider.overrideWith((ref) => Locale(language)),
            quranBookProvider.overrideWith((ref) => book),
          ],
          child: DiniApp(router: createRouter(initialLocation: location)),
        ),
      );
      await tester.pumpAndSettle();
      return storage;
    }

    testWidgets('sûreye dokununca Mushaf o sûrenin sayfasında açılır', (
      tester,
    ) async {
      final storage = await open(tester, '/quran');
      expect(find.text('Fâtiha'), findsOneWidget);
      expect(find.text('Kaldığın yerden devam et'), findsNothing);

      await tester.tap(find.text('Bakara'));
      await tester.pumpAndSettle();

      expect(find.byType(QuranReaderPage), findsOneWidget);
      expect(find.text('Bakara · Sayfa 2'), findsOneWidget);
      // Sekmenin içinde açılır: sahne bir kez çizilir.
      expect(find.byType(MosqueScene), findsOneWidget);
      expect(storage.values['dini.quran.lastPage'], '2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('cüzler listesi', (tester) async {
      await open(tester, '/quran');
      await tester.tap(find.text('Cüzler'));
      await tester.pumpAndSettle();
      expect(find.text('1. Cüz'), findsOneWidget);
      expect(find.text('Fâtiha 1 · Sayfa 1'), findsOneWidget);
    });

    testWidgets('kaldığın yer saklanır ve oradan açılır', (tester) async {
      await open(tester, '/quran', saved: {'dini.quran.lastPage': '42'});
      expect(find.text('Kaldığın yerden devam et'), findsOneWidget);
      expect(find.text('Bakara · Sayfa 42 · 3. Cüz'), findsOneWidget);

      await tester.tap(find.text('Kaldığın yerden devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Bakara · Sayfa 42'), findsOneWidget);
    });

    testWidgets('sayfa çevrilince yeni sayfa kaldığın yer olur', (
      tester,
    ) async {
      final storage = await open(tester, QuranReaderPage.routeFor(2));
      final turner = tester.getRect(find.byType(MushafPage));
      // Sağ kenara dokunmak ileri çevirir.
      await tester.tapAt(Offset(turner.right - 10, turner.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Bakara · Sayfa 3'), findsOneWidget);
      expect(storage.values['dini.quran.lastPage'], '3');
    });

    for (final (page, size) in [
      (1, const Size(390, 844)),
      (2, const Size(390, 844)),
      (50, const Size(390, 844)),
      (604, const Size(390, 844)),
      (50, const Size(320, 568)),
      (293, const Size(768, 1024)),
    ]) {
      testWidgets('$page. sayfa ${size.width.round()} genişlikte taşmaz', (
        tester,
      ) async {
        await open(tester, QuranReaderPage.routeFor(page), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(MushafPage), findsOneWidget);
      });
    }

    // Başlık ve Besmele'li sayfalar da: 604. sayfada üç sûre başlar ve
    // ölçüm başlıkları yanlış sayınca Nâs çerçevenin dışına taşıyordu.
    for (final page in [1, 50, 293, 604]) {
      testWidgets('$page. sayfa, sığacak en büyük boyla yazılır', (
        tester,
      ) async {
        await open(tester, QuranReaderPage.routeFor(page));
        final area = tester.getRect(find.byType(SingleChildScrollView));
        final content = tester.getRect(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Column),
              )
              .first,
        );
        // Sığar: kaydırmaya gerek kalmaz.
        expect(content.height, lessThanOrEqualTo(area.height + .5));
        // Ama boşa yer bırakılmaz: alanın çoğu doludur (ilk sayfa kısa
        // olduğu için en büyük boyda bile yarısını doldurur).
        expect(
          content.height,
          greaterThan(area.height * (page == 1 ? .5 : .8)),
        );
      });
    }

    testWidgets('İngilizce: sûre meal ile okunur, kaynak yazılır', (
      tester,
    ) async {
      await open(tester, QuranReaderPage.routeFor(1), language: 'en');
      await tester.tap(find.byTooltip('Read with translation'));
      await tester.pumpAndSettle();

      expect(find.byType(QuranMealPage), findsOneWidget);
      expect(find.byType(MosqueScene), findsOneWidget);
      expect(
        find.text('Praise be to Allah, Lord of the Worlds,'),
        findsOneWidget,
      );
      await tester.dragUntilVisible(
        find.textContaining('Pickthall'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.textContaining('Pickthall'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arapça okuyana meal düğmesi görünmez', (tester) async {
      await open(tester, QuranReaderPage.routeFor(1), language: 'ar');
      expect(find.byTooltip('اقرأ مع الترجمة'), findsNothing);
    });

    testWidgets('Türkçe: sûre Elmalılı meali ile okunur, kaynak yazılır', (
      tester,
    ) async {
      await open(tester, QuranReaderPage.routeFor(604));
      await tester.tap(find.byTooltip('Meal ile oku'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranMealPage), findsOneWidget);
      expect(find.text('De, o: Allah tek bir (ehad)dir'), findsOneWidget);
      await tester.dragUntilVisible(
        find.textContaining('namazzamani.net'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.textContaining('Elmalılı'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mealin Elmalılı\'ya ait olduğu yazar, adına dokununca '
        'hakkında yazısı açılır', (tester) async {
      await open(tester, QuranMealPage.routeFor(1));
      final name = find.text('Meal: Elmalılı Muhammed Hamdi Yazır');
      expect(name, findsOneWidget);

      await tester.tap(name);
      await tester.pumpAndSettle();
      expect(find.byType(TranslatorAboutSheet), findsOneWidget);
      expect(
        find.text('Elmalılı Muhammed Hamdi Yazır (1878-1942)'),
        findsOneWidget,
      );
      expect(find.textContaining('Hak Dini Kur\'an Dili'), findsWidgets);
      final ataturk = find.textContaining('Osman Ergin\'in aktardığına göre');
      await tester.dragUntilVisible(
        ataturk,
        find.descendant(
          of: find.byType(TranslatorAboutSheet),
          matching: find.byType(ListView),
        ),
        const Offset(0, -200),
      );
      expect(ataturk, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('İngilizcede mütercim adı yazar, hakkında yazısı yok', (
      tester,
    ) async {
      await open(tester, QuranMealPage.routeFor(1), language: 'en');
      expect(find.text('Translation: Marmaduke Pickthall'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('birlikte çevrilen âyette meal yinelenmez, söylenir', (
      tester,
    ) async {
      await open(tester, QuranMealPage.routeFor(81));
      final note = find.text(
        '(Bu âyetin meali bir önceki âyetle birlikte verilmiştir.)',
      );
      await tester.dragUntilVisible(
        note,
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(note, findsOneWidget);
      // Ortak cümle yalnızca bir kez, 8. âyetin altında.
      expect(find.textContaining('(8-9)'), findsOneWidget);
    });

    testWidgets('Arapça: Mushaf ve sûre listesi sağdan sola', (tester) async {
      await open(tester, '/quran', language: 'ar');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('البقرة').first);
      await tester.pumpAndSettle();
      expect(find.byType(MushafPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
