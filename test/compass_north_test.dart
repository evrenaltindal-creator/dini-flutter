import 'package:dini_flutter/features/qibla/data/magnetic_declination.dart';
import 'package:dini_flutter/features/qibla/domain/compass_north.dart';
import 'package:dini_flutter/features/qibla/domain/qibla_calculator.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/qibla/presentation/qibla_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(MagneticDeclinationService service, {String languageCode = 'tr'}) =>
    ProviderScope(
      child: MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QiblaPage(declinationService: service),
      ),
    );

const _ankara = Coordinates(39.9334, 32.8597);

/// Ayar kaydedilmemişken uygulamanın kullandığı konum (İstanbul).
const _defaultLocation = Coordinates(41.0082, 28.9784);

void main() {
  group('CompassNorth', () {
    test('gerçek kuzey veren platformda okuma değişmez', () {
      // iOS, CLHeading.trueHeading verir; düzeltme uygulanırsa iki kez
      // düzeltilmiş olur ve ok bu kez ters yöne kayar.
      const north = CompassNorth(readingIsTrueNorth: true);
      expect(north.toTrue(155), 155);
      expect(north.toTrue(0), 0);
      expect(north.isKnown, isTrue);
    });

    test('manyetik okuma sapma kadar kaydırılır', () {
      // Android, SensorManager.getOrientation ile manyetik kuzeye göre ölçer.
      const north = CompassNorth(declination: 5.2, readingIsTrueNorth: false);
      expect(north.toTrue(155), closeTo(160.2, 0.001));
    });

    test('çevrim 0-360 aralığında kalır', () {
      const east = CompassNorth(declination: 10, readingIsTrueNorth: false);
      expect(east.toTrue(355), closeTo(5, 0.001));

      const west = CompassNorth(declination: -10, readingIsTrueNorth: false);
      expect(west.toTrue(5), closeTo(355, 0.001));
    });

    test('manyetik karşılık, gerçek açının tersine çevrimidir', () {
      const north = CompassNorth(declination: 5.2, readingIsTrueNorth: false);
      final trueBearing = const QiblaCalculator().bearing(_ankara);
      final magnetic = north.toMagnetic(trueBearing);

      expect(magnetic, closeTo(trueBearing - 5.2, 0.001));
      // İki çevrim birbirini geri almalı.
      expect(north.toTrue(magnetic), closeTo(trueBearing, 0.001));
    });

    test('sapma bilinmiyorsa isKnown false kalır', () {
      // Bilinmeyen sapmayı sıfır gibi göstermek, kullanıcıya olduğundan
      // kesin bir yön sunmak olur.
      const unknown = CompassNorth(readingIsTrueNorth: false);
      expect(unknown.isKnown, isFalse);
    });
  });

  group('MagneticDeclinationService', () {
    test('gerçek kuzey veren platformda sapma hiç sorulmaz', () async {
      var calls = 0;
      final service = MagneticDeclinationService(
        readingIsTrueNorth: true,
        read: (_) async {
          calls++;
          return 5.2;
        },
      );

      final north = await service.resolve(_ankara);
      expect(calls, 0);
      expect(north.readingIsTrueNorth, isTrue);
      expect(north.toTrue(155), 155);
    });

    test('manyetik platformda sapma okunur ve uygulanır', () async {
      final service = MagneticDeclinationService(
        readingIsTrueNorth: false,
        read: (where) async {
          expect(where.latitude, _ankara.latitude);
          expect(where.longitude, _ankara.longitude);
          return 5.2;
        },
      );

      final north = await service.resolve(_ankara);
      expect(north.readingIsTrueNorth, isFalse);
      expect(north.declination, 5.2);
      expect(north.toTrue(155), closeTo(160.2, 0.001));
    });

    test('platform kanalı yoksa hata sızmaz', () async {
      // Kanal kayıtlı değilken (eski sürüm, desteklenmeyen platform) pusula
      // yine çalışmalı; düzeltmesiz ama çalışır.
      final service = MagneticDeclinationService(
        readingIsTrueNorth: false,
        read: (_) async => throw MissingPluginException(),
      );

      final north = await service.resolve(_ankara);
      expect(north.declination, 0);
      expect(north.isKnown, isFalse);
    });

    test('platform null dönerse düzeltme uygulanmaz', () async {
      final service = MagneticDeclinationService(
        readingIsTrueNorth: false,
        read: (_) async => null,
      );

      final north = await service.resolve(_ankara);
      expect(north.declination, 0);
      expect(north.isKnown, isFalse);
    });
  });

  group('kıble açısı', () {
    test('Ankara için gerçek kuzeye göre açı', () {
      // Büyük daire yönü. Bu değer manyetik pusulada sapma kadar farklı
      // okunur; ekran ikisini ayrı ayrı gösterir.
      expect(const QiblaCalculator().bearing(_ankara), closeTo(160.2, 0.5));
    });

    test('Kâbe yönü, kuzeyden bakınca güneye işaret eder', () {
      // Mekke'nin kuzeyindeki bir nokta güneye dönmelidir; hesabın işareti
      // ters olsaydı bu 0 dereceye yakın çıkardı.
      const north = Coordinates(31.4225, 39.8262);
      expect(const QiblaCalculator().bearing(north), closeTo(180, 0.5));
    });
  });

  group('kıble ekranı hangi kuzeyi gösterdiğini söyler', () {
    testWidgets('manyetik platformda iki açı birden görünür', (tester) async {
      // Kullanıcı basılı bir çizelgede 155° görüp uygulamada 160° görünce
      // hangisinin doğru olduğunu bilemiyordu. Ekran ikisini de yazar.
      await tester.pumpWidget(
        _app(
          MagneticDeclinationService(
            readingIsTrueNorth: false,
            read: (_) async => 5.2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Varsayılan konumun kıble açısı ve onun manyetik karşılığı.
      const north = CompassNorth(declination: 5.2, readingIsTrueNorth: false);
      final trueBearing = const QiblaCalculator().bearing(_defaultLocation);
      final magnetic = north.toMagnetic(trueBearing);
      expect(
        magnetic.round(),
        isNot(trueBearing.round()),
        reason: 'Sapma uygulanmazsa bu test hiçbir şey kanıtlamaz.',
      );

      expect(find.textContaining('${trueBearing.round()}'), findsWidgets);
      expect(
        find.textContaining('${magnetic.round()}'),
        findsWidgets,
        reason:
            'Manyetik karşılık gösterilmiyor; kullanıcı yayımlanan açıyla '
            'karşılaştıramaz.',
      );
    });

    testWidgets('gerçek kuzey veren platformda tek açı ve açıklama', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(MagneticDeclinationService(readingIsTrueNorth: true)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(const AppLocalizations(Locale('tr')).text('qibla.northTrue')),
        findsOneWidget,
      );
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde kuzey açıklaması çizilir', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(
            MagneticDeclinationService(
              readingIsTrueNorth: false,
              read: (_) async => 5.2,
            ),
            languageCode: language,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
