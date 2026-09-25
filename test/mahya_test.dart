import 'dart:io';
import 'dart:ui' as ui;

import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/home/domain/mosque_scene_state.dart';
import 'package:dini_flutter/features/home/presentation/mosque_backdrop.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/ramadan/domain/mahya.dart';
import 'package:dini_flutter/features/ramadan/domain/mahya_geometry.dart';
import 'package:dini_flutter/features/ramadan/presentation/mahya_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ramazan 1447: 18 Şubat 2026 – 19 Mart 2026 (otuz gün), bayram 20 Mart.
/// Tarihler uygulamanın kendi takviminden okundu, elle yazılmadı.
final ramadanFirst = DateTime(2026, 2, 18);
final ramadanLast = DateTime(2026, 3, 19);
final eidFirst = DateTime(2026, 3, 20);

DateTime ramadanDay(int day) => ramadanFirst.add(Duration(days: day - 1));

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

  group('hangi gece hangi yazı', () {
    test('Ramazan dışında mahya yanmaz', () {
      expect(mahyaFor(DateTime(2026, 6, 1), afterMaghrib: false), isNull);
      expect(mahyaFor(DateTime(2026, 6, 1), afterMaghrib: true), isNull);
    });

    test('Ramazan\'dan önceki akşam ilk gece sayılır', () {
      // Hicri gün akşam başlar: ilk orucun tutulacağı günün gecesi bir önceki
      // akşam başlar ve mahya o akşam yanar.
      final eve = mahyaFor(
        ramadanFirst.subtract(const Duration(days: 1)),
        afterMaghrib: true,
      );
      expect(eve?.textKey, 'mahya.welcome');
      expect(eve?.nightOfRamadan, 1);

      // Aynı akşam, akşam ezanından önce henüz Ramazan değildir.
      expect(
        mahyaFor(
          ramadanFirst.subtract(const Duration(days: 1)),
          afterMaghrib: false,
        ),
        isNull,
      );
    });

    test('ilk günün sabaha karşısı hâlâ birinci gecedir', () {
      final beforeDawn = mahyaFor(ramadanFirst, afterMaghrib: false);
      expect(beforeDawn?.textKey, 'mahya.welcome');
      expect(beforeDawn?.nightOfRamadan, 1);
    });

    test('yazı haftada bir değişir', () {
      // Kullanıcının istediği davranış: her gece değil, hafta hafta değişsin.
      String keyOfNight(int night) =>
          mahyaFor(ramadanDay(night), afterMaghrib: false)!.textKey;

      expect(keyOfNight(2), 'mahya.week1');
      expect(keyOfNight(7), 'mahya.week1');
      expect(keyOfNight(8), 'mahya.week2');
      expect(keyOfNight(14), 'mahya.week2');
      expect(keyOfNight(15), 'mahya.week3');
      expect(keyOfNight(22), 'mahya.week4');
    });

    test('Kadir Gecesi\'nin kendi yazısı var', () {
      expect(
        mahyaFor(ramadanDay(mahyaQadrNight), afterMaghrib: false)?.textKey,
        'mahya.qadr',
      );
    });

    test('son gece veda yazısı yanar', () {
      // Ramazan 29 ya da 30 gün sürer; son gece hesapla değil, ertesi günün
      // hicri ayına bakılarak bulunur.
      final last = mahyaFor(ramadanLast, afterMaghrib: false);
      expect(last?.textKey, 'mahya.farewell');
      expect(last?.nightOfRamadan, 30);
    });

    test('bayram gecesi bayram yazısı yanar', () {
      expect(mahyaFor(ramadanLast, afterMaghrib: true)?.textKey, 'mahya.eid');
      expect(mahyaFor(eidFirst, afterMaghrib: false)?.textKey, 'mahya.eid');
    });

    test('Ramazan boyunca her gecenin bir yazısı var', () {
      for (var night = 1; night <= 30; night++) {
        final mahya = mahyaFor(ramadanDay(night), afterMaghrib: false);
        expect(mahya, isNotNull, reason: '$night. gecede mahya yok.');
        for (final language in ['tr', 'en', 'ar']) {
          expect(
            AppLocalizations(Locale(language)).text(mahya!.textKey),
            isNot(mahya.textKey),
            reason: '${mahya.textKey} $language dilinde yok.',
          );
        }
      }
    });
  });

  group('ne zaman yanar', () {
    test('akşamdan imsağa kadar yanar', () {
      for (final period in [
        MosqueScenePeriod.maghrib,
        MosqueScenePeriod.ishaNight,
        MosqueScenePeriod.preFajrNight,
      ]) {
        expect(mahyaIsLit(period), isTrue, reason: '$period gece sayılmadı.');
      }
    });

    test('gündüz sönüktür', () {
      for (final period in [
        MosqueScenePeriod.fajr,
        MosqueScenePeriod.sunrise,
        MosqueScenePeriod.day,
        MosqueScenePeriod.dhuhr,
        MosqueScenePeriod.asr,
        MosqueScenePeriod.goldenHour,
      ]) {
        expect(mahyaIsLit(period), isFalse, reason: '$period gündüzdür.');
      }
    });

    test('yalnızca akşamla yatsı arası ertesi geceye sayılır', () {
      expect(mahyaAfterMaghrib(MosqueScenePeriod.maghrib), isTrue);
      expect(mahyaAfterMaghrib(MosqueScenePeriod.ishaNight), isTrue);
      // Gece yarısını geçtikten sonra takvim günü zaten ilerlemiştir;
      // bir gün daha eklemek mahyayı bir gece ileri kaydırırdı.
      expect(mahyaAfterMaghrib(MosqueScenePeriod.preFajrNight), isFalse);
    });
  });

  group('minarelerin ekrandaki yeri', () {
    test('sahne görselinin boyutu sabitle aynı', () {
      // Minare yerleri görselin oranına bağlı; yeni bir görsel farklı oranda
      // gelirse mahya boşluğa asılır.
      for (final name in [
        'mosque_night.png',
        'mosque_dawn.png',
        'mosque_day.png',
        'mosque_asr.png',
      ]) {
        final bytes = File('assets/scenes/$name').readAsBytesSync();
        final width = bytes.buffer.asByteData().getUint32(16);
        final height = bytes.buffer.asByteData().getUint32(20);
        final ratio = width / height;
        expect(
          ratio,
          closeTo(mosqueSceneImageSize.aspectRatio, .005),
          reason: '$name farklı oranda; mahya çapaları kayar.',
        );
      }
    });

    test('telefon ekranında uçlar minarelere oturur', () {
      // Görsel ekrandan dar oranlı: genişlik tam oturur, alt kırpılır.
      const screen = Size(390, 844);
      final anchors = mahyaAnchors(
        screen: screen,
        image: mosqueSceneImageSize,
      )!;

      expect(anchors.left.dx, closeTo(mahyaLeftAnchor.dx * 390, 1));
      expect(anchors.right.dx, closeTo(mahyaRightAnchor.dx * 390, 1));
      // Şerefe hizası görselin yüksekliğine göre ölçeklenir, ekranın
      // yüksekliğine göre değil: kırpma hesaba katılmazsa mahya kayar.
      final scale = 390 / mosqueSceneImageSize.width;
      expect(
        anchors.left.dy,
        closeTo(mahyaLeftAnchor.dy * mosqueSceneImageSize.height * scale, 1),
      );
      expect(anchors.sag.dy, greaterThan(anchors.left.dy));
    });

    test('geniş pencerede uçlar ekran içinde kalır', () {
      // Yatay pencerede görselin yanları kırpılır; minareler ekran dışına
      // çıkar. Uçlar kenara çekilmezse kablo görünmez bir yere asılır.
      const screen = Size(1200, 700);
      final anchors = mahyaAnchors(screen: screen, image: mosqueSceneImageSize);
      if (anchors != null) {
        expect(anchors.left.dx, greaterThanOrEqualTo(0));
        expect(anchors.right.dx, lessThanOrEqualTo(screen.width));
        expect(anchors.width, greaterThanOrEqualTo(mahyaMinimumWidth));
      }
    });

    test('çok dar pencerede mahya çizilmez', () {
      expect(
        mahyaAnchors(screen: const Size(120, 800), image: mosqueSceneImageSize),
        isNull,
        reason: 'Okunmayacak kadar dar bir mahya çizilmemeli.',
      );
      expect(
        mahyaAnchors(screen: Size.zero, image: mosqueSceneImageSize),
        isNull,
      );
    });
  });

  group('çizim', () {
    testWidgets('yazı üç dilde de çizilir ve taşma yaratmaz', (tester) async {
      for (final language in ['tr', 'en', 'ar']) {
        await tester.pumpWidget(
          _app(
            Center(
              child: SizedBox(
                width: 320,
                height: 700,
                child: MahyaView(
                  text: AppLocalizations(Locale(language))
                      .text('mahya.welcome'),
                  semanticsLabel: 'mahya',
                  imageSize: mosqueSceneImageSize,
                ),
              ),
            ),
            languageCode: language,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$language taşıyor.');
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('dar pencerede hiç çizilmez', (tester) async {
      await tester.pumpWidget(
        _app(
          // Center: MaterialApp'ın içinde SizedBox ekranın tamamına
          // genişliyordu; test 100 piksel yerine 800×600'ü deniyordu.
          const Center(
            child: SizedBox(
              width: 100,
              height: 700,
              child: MahyaView(
                text: 'Hoş geldin',
                semanticsLabel: 'mahya',
                imageSize: mosqueSceneImageSize,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((paint) => paint.painter is MahyaPainter),
        isEmpty,
      );
    });
  });

  group('yazı gerçekten çiziliyor', () {
    /// Boyacıyı doğrudan çalıştırıp çizdiği resmi geri okur.
    ///
    /// Widget testi burada yetmiyor: boyama sırasında atılan hata yazıyı
    /// sessizce düşürüyor, ekranda yalnızca kablo kalıyordu ve test yine
    /// geçiyordu. Tek güvenilir kanıt, piksellere bakmaktır.
    Future<int> litPixels(
      String text, {
      Size screen = const Size(390, 844),
    }) async {
      final anchors = mahyaAnchors(
        screen: screen,
        image: mosqueSceneImageSize,
      )!;
      final recorder = ui.PictureRecorder();
      MahyaPainter(
        text: text,
        anchors: anchors,
        opacity: 1,
        textDirection: TextDirection.ltr,
      ).paint(Canvas(recorder), screen);
      final image = await recorder.endRecording().toImage(
        screen.width.toInt(),
        screen.height.toInt(),
      );
      final data = (await image.toByteData())!;
      // Yazı kablonun altındaki şeritte durur; kablonun kendi pikselleri
      // sayıma karışmasın diye yalnızca o şerit taranır.
      var lit = 0;
      final from = (anchors.sag.dy + 6).toInt();
      final to = (anchors.sag.dy + 40).clamp(0, screen.height - 1).toInt();
      for (var y = from; y < to; y++) {
        for (var x = 0; x < screen.width.toInt(); x++) {
          final alpha = data.getUint8(((y * screen.width.toInt()) + x) * 4 + 3);
          if (alpha > 40) lit++;
        }
      }
      return lit;
    }

    test('uzun yazı da çizilir', () async {
      // Uzun cümle yazı boyutunu küçültme yoluna sokar; o yolda yazı
      // çizilmeden kalıyordu.
      expect(
        await litPixels('Ramazan-ı şerif mübarek olsun'),
        greaterThan(200),
        reason: 'Kablo çizildi ama yazı yok.',
      );
    });

    test('kısa yazı da çizilir', () async {
      expect(await litPixels('Elveda'), greaterThan(200));
    });

    test('Arapça yazı da çizilir', () async {
      expect(await litPixels('عيدكم مبارك'), greaterThan(200));
    });
  });

  group('arka planla birlikte', () {
    Widget backdrop(
      DateTime now, {
      BackdropScrim scrim = BackdropScrim.light,
    }) => ProviderScope(
      overrides: [clockProvider.overrideWithValue(() => now)],
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MosqueBackdrop(scrim: scrim, child: const SizedBox.shrink()),
      ),
    );

    testWidgets('Ramazan gecesinde mahya yanar', (tester) async {
      await tester.pumpWidget(backdrop(DateTime(2026, 2, 20, 21, 30)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MahyaView), findsOneWidget);
      expect(find.byType(MosqueScene), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ramazan gündüzünde mahya yanmaz', (tester) async {
      await tester.pumpWidget(backdrop(DateTime(2026, 2, 20, 13, 0)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(MahyaView),
        findsNothing,
        reason:
            'Mahya gündüz yanmaz; ışığı görünmez, yazı ise fotoğrafı bozar.',
      );
    });

    testWidgets('Ramazan dışındaki gecede mahya yanmaz', (tester) async {
      await tester.pumpWidget(backdrop(DateTime(2026, 6, 10, 22, 0)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MahyaView), findsNothing);
    });
  });
}
