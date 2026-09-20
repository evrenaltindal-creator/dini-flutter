import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/domain/islamic_calendar.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/ramadan/data/teravih_repository.dart';
import 'package:dini_flutter/features/ramadan/domain/fasting_log.dart';
import 'package:dini_flutter/features/ramadan/domain/ramadan_night.dart';
import 'package:dini_flutter/features/ramadan/domain/teravih.dart';
import 'package:dini_flutter/features/ramadan/presentation/teravih_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Ramazan 1447: 18 Şubat – 19 Mart 2026.
final ramadanFirst = DateTime(2026, 2, 18);

Widget _app({
  required LocalStorage storage,
  required DateTime now,
  String languageCode = 'tr',
}) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    clockProvider.overrideWithValue(() => now),
  ],
  child: MaterialApp(
    locale: Locale(languageCode),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const TeravihPage(),
  ),
);

void main() {
  setUpAll(TimezoneService.initialize);

  group('gece hangi güne yazılır', () {
    test('akşamdan sonra gece ertesi güne aittir', () {
      // Yatsıdan sonra kılınan teravih o geceye yazılmalı. Akşamı
      // saymazsak Ramazan\'ın ilk teravihi bir gün geriye düşerdi.
      expect(
        ramadanNightOf(
          ramadanFirst.subtract(const Duration(days: 1)),
          afterMaghrib: true,
        ),
        1,
      );
      expect(
        ramadanNightOf(
          ramadanFirst.subtract(const Duration(days: 1)),
          afterMaghrib: false,
        ),
        isNull,
      );
    });

    test('gece yarısından sonra gün zaten ilerlemiştir', () {
      // Sabaha karşı takvim günü ertesi gündür; bir gün daha eklemek
      // teravihi bir gece ileri kaydırırdı.
      expect(
        ramadanNightOf(
          ramadanFirst.add(const Duration(days: 4)),
          afterMaghrib: false,
        ),
        5,
      );
    });

    test('Ramazan dışında gece yoktur', () {
      expect(ramadanNightOf(DateTime(2026, 6, 1), afterMaghrib: true), isNull);
    });

    test('tarih düzeltmesi geceyi kaydırır', () {
      expect(
        ramadanNightOf(
          ramadanFirst,
          afterMaghrib: false,
          calendar: const IslamicCalendar(dayOffset: 1),
        ),
        2,
      );
    });
  });

  group('sayaç', () {
    final span = ramadanSpanFor(DateTime(2026, 3, 1))!;

    test('selam selam ilerler', () {
      var log = TeravihLog(span: span);
      log = log.withNight(3, log.rekatsOf(3) + teravihStep);
      log = log.withNight(3, log.rekatsOf(3) + teravihStep);
      expect(log.rekatsOf(3), 4);
      expect(
        teravihStep,
        2,
        reason: 'Teravih iki rekâtta bir selamla kılınır.',
      );
    });

    test('sıfırın altına inmez', () {
      final log = TeravihLog(span: span).withNight(2, -4);
      expect(log.rekatsOf(2), 0);
      expect(log.nightsPrayed, 0);
    });

    test('hedefin üstüne çıkabilir', () {
      // Camiye göre kılınan rekât değişir; sayacı hedefte kilitlemek
      // kullanıcıyı yanlış bir sayıya zorlardı.
      final log = TeravihLog(span: span, target: 20).withNight(1, 24);
      expect(log.rekatsOf(1), 24);
      expect(log.nightsCompleted, 1);
    });

    test('geceler ve toplam sayılır', () {
      final log = TeravihLog(
        span: span,
        target: 20,
      ).withNight(1, 20).withNight(2, 8).withNight(3, 20);
      expect(log.nightsPrayed, 3);
      expect(log.nightsCompleted, 2);
      expect(log.totalRekats, 48);
    });

    test('hedef seçenekleri hüküm değildir', () {
      // Sekiz ve yirmi farklı uygulamalardır; varsayılan Türkiye'de
      // camilerde kılınan sayıdır.
      expect(teravihTargetChoices, containsAll([8, 20]));
      expect(teravihDefaultTarget, 20);
    });

    test('depo hicri yıla göre saklar', () async {
      final storage = _MemoryStorage();
      final repository = TeravihRepository(storage);

      await repository.saveNight(span, 5, 20);
      expect(storage.values['dini.teravih.1447.5'], '20');

      await repository.saveTarget(8);
      final log = await repository.load(span);
      expect(log.rekatsOf(5), 20);
      expect(log.target, 8);

      await repository.saveNight(span, 5, 0);
      expect(storage.values.containsKey('dini.teravih.1447.5'), isFalse);
    });

    test('bozuk kayıt sayılmaz', () async {
      final storage = _MemoryStorage();
      storage.values['dini.teravih.1447.4'] = 'yirmi';
      final log = await TeravihRepository(storage).load(span);
      expect(log.rekatsOf(4), 0);
      expect(log.target, teravihDefaultTarget);
    });
  });

  group('vakitlerin günü', () {
    // Bu hatayı teravih sayacı ortaya çıkardı: gecenin hangi güne yazıldığı
    // akşam vaktine bakılarak bulunuyor, akşam vakti de vakit tablosundan
    // geliyor. Tablo cihazın gününe göre hesaplanırsa, cihazın saat dilimi
    // seçilen şehirden farklı olduğunda (yolculuk ya da listeden başka bir
    // şehir) gece yarısı civarında bütün vakitler bir gün kayar.
    test('vakitler seçilen şehrin gününe göre hesaplanır', () {
      // 20 Şubat 22:00 UTC, İstanbul'da 21 Şubat 01:00'dir.
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 2, 20, 22)),
        ],
      );
      addTearDown(container.dispose);

      final times = container.read(prayerTimesProvider);
      expect(
        times.date,
        DateTime(2026, 2, 21),
        reason: 'Vakitler cihazın gününe göre hesaplanmış.',
      );
    });
  });

  group('ekran', () {
    testWidgets('bir selam iki rekât ekler ve kaydedilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      // Ramazan'ın üçüncü günü, İstanbul'da akşamdan sonra: dördüncü gece.
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 2, 20, 19, 0)),
      );
      await tester.pumpAndSettle();

      expect(find.text('4. gece'), findsWidgets);

      await tester.tap(find.text('Bir selam (2 rekât)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bir selam (2 rekât)'));
      await tester.pumpAndSettle();

      expect(storage.values['dini.teravih.1447.4'], '4');
      expect(find.text('4 / 20 rekât'), findsOneWidget);
    });

    testWidgets('geri al bir selam düşer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      storage.values['dini.teravih.1447.4'] = '6';
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 2, 20, 19, 0)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();

      expect(storage.values['dini.teravih.1447.4'], '4');
    });

    testWidgets('hedef değiştirilebilir ve kalıcıdır', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 2, 20, 19, 0)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('8 rekât'));
      await tester.pumpAndSettle();

      expect(storage.values['dini.teravih.target'], '8');
    });

    testWidgets('Ramazan dışında sayaç yerine açıklama çıkar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(storage: _MemoryStorage(), now: DateTime(2026, 6, 10, 19, 0)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ramazan gecelerinde çalışır'),
        findsOneWidget,
      );
      expect(find.text('Bir selam (2 rekât)'), findsNothing);
      // Kayıt yine görünür: geçmiş geceler burada sayılır.
      expect(find.textContaining('gece kılındı'), findsOneWidget);
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde dar ekranda taşmaz', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(
            storage: _MemoryStorage(),
            now: DateTime(2026, 2, 20, 19, 0),
            languageCode: language,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppLocalizations(Locale(language)).text('teravih.title')),
          findsOneWidget,
        );
      });
    }
  });
}
