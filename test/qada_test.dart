import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/tracker/data/qada_repository.dart';
import 'package:dini_flutter/features/tracker/domain/prayer_tracker.dart';
import 'package:dini_flutter/features/tracker/domain/qada.dart';
import 'package:dini_flutter/features/tracker/presentation/qada_page.dart';
import 'package:dini_flutter/shared/models/domain.dart';
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

Widget _app({required LocalStorage storage, String languageCode = 'tr'}) =>
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const QadaPage(),
      ),
    );

void main() {
  group('sayaç', () {
    test('boş kayıtta toplam sıfırdır', () {
      const log = QadaLog();
      expect(log.total, 0);
      expect(log.isEmpty, isTrue);
      expect(log.countOf(Prayer.fajr), 0);
    });

    test('gün eklemek beş vakte birden yazar', () {
      // Biriken kaza gün olarak hatırlanır; beş vakti tek tek girmek
      // kullanıcıya bırakılırsa sayı kolayca tutmaz.
      final log = const QadaLog().addDays(3);
      for (final prayer in trackedPrayers) {
        expect(log.countOf(prayer), 3, reason: '${prayer.name} eksik.');
      }
      expect(log.total, 15);
    });

    test('sıfır ya da eksi gün eklenmez', () {
      expect(const QadaLog().addDays(0).total, 0);
      expect(const QadaLog().addDays(-5).total, 0);
    });

    test('sayı sıfırın altına inmez', () {
      // Eksi kaza anlamsızdır ve toplamı sessizce bozardı.
      final log = const QadaLog()
          .withPrayer(Prayer.asr, 1)
          .withPrayer(Prayer.asr, -3);
      expect(log.countOf(Prayer.asr), 0);
      expect(log.total, 0);
    });

    test('bir kaza kılınca o vakit düşer', () {
      final log = const QadaLog().addDays(2);
      final next = log.withPrayer(Prayer.isha, log.countOf(Prayer.isha) - 1);
      expect(next.countOf(Prayer.isha), 1);
      expect(next.countOf(Prayer.fajr), 2, reason: 'Diğer vakitler etkilendi.');
      expect(next.total, 9);
    });

    test('güneş vakti kazaya girmez', () {
      // Güneş bir namaz vakti değildir; sayaç yalnızca beş farzı tutar.
      expect(trackedPrayers, isNot(contains(Prayer.sunrise)));
      expect(const QadaLog().addDays(1).total, trackedPrayers.length);
    });

    test('yazılan kayıt geri okunur', () async {
      final storage = _MemoryStorage();
      final repository = QadaRepository(storage);

      await repository.save(const QadaLog().addDays(2));
      expect(storage.values['dini.qada.fajr'], '2');

      final log = await repository.load();
      expect(log.total, 10);

      // Sıfırlanan vakit depoda iz bırakmamalı.
      await repository.save(log.withPrayer(Prayer.fajr, 0));
      expect(storage.values.containsKey('dini.qada.fajr'), isFalse);
      expect((await repository.load()).total, 8);
    });

    test('bozuk kayıt sıfır sayılır', () async {
      final storage = _MemoryStorage();
      storage.values['dini.qada.asr'] = 'çok';
      expect((await QadaRepository(storage).load()).total, 0);
    });
  });

  group('ekran', () {
    testWidgets('gün eklemek ekranda ve depoda görünür', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();

      expect(find.text('Kayıtlı kaza yok.'), findsOneWidget);

      await tester.tap(find.text('7 gün ekle'));
      await tester.pumpAndSettle();

      expect(storage.values['dini.qada.dhuhr'], '7');
      expect(find.text('Toplam 35 kaza'), findsOneWidget);
    });

    testWidgets('bir kaza kılmak sayıyı düşürür', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      await QadaRepository(storage).save(const QadaLog().addDays(1));

      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Toplam 4 kaza'), findsOneWidget);
      expect(storage.values.containsKey('dini.qada.fajr'), isFalse);
    });

    testWidgets('kaza yokken düşürme düğmesi kapalıdır', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(storage: _MemoryStorage()));
      await tester.pumpAndSettle();

      final buttons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      expect(buttons, isNotEmpty);
      expect(
        buttons.every((button) => button.onPressed == null),
        isTrue,
        reason: 'Kılınacak kaza yokken düğme açık kalmamalı.',
      );
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde dar ekranda taşmaz', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(storage: _MemoryStorage(), languageCode: language),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppLocalizations(Locale(language)).text('qada.title')),
          findsOneWidget,
        );
      });
    }
  });
}
