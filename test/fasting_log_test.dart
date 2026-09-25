import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/domain/islamic_calendar.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/ramadan/data/fasting_repository.dart';
import 'package:dini_flutter/features/ramadan/domain/fasting_log.dart';
import 'package:dini_flutter/features/ramadan/presentation/fasting_page.dart';
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

/// Ramazan'ı yirmi dokuz gün süren sahte takvim.
///
/// Uygulamanın tabular takviminde Ramazan (tek numaralı ay) her zaman otuz
/// gündür; yirmi dokuz günlük bir Ramazan gerçek takvimle üretilemez. Gün
/// sayısının sabit yazılmayıp sayıldığını yine de kanıtlamak gerekir: takvim
/// bir gün gözleme dayalı bir kaynakla değiştirilirse son gün kayar.
class _ShortRamadanCalendar extends IslamicCalendar {
  const _ShortRamadanCalendar();

  /// Ramazan 1 Mart 2026'da başlar ve yirmi dokuz gün sürer.
  static final first = DateTime(2026, 3, 1);

  @override
  IslamicDate hijri(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final offset = day.difference(first).inDays;
    if (offset >= 0 && offset < 29) return IslamicDate(1447, 9, offset + 1);
    return IslamicDate(1447, offset < 0 ? 8 : 10, 1);
  }
}

/// Ramazan 1447: 18 Şubat – 19 Mart 2026, otuz gün.
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
    home: const FastingPage(),
  ),
);

void main() {
  setUpAll(TimezoneService.initialize);

  group('Ramazan\'ın takvimdeki yeri', () {
    test('gün sayısı sayılarak bulunur', () {
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      expect(span.firstDay, ramadanFirst);
      expect(span.hijriYear, 1447);
      // Ramazan 29 ya da 30 gün sürer; otuza sabitlemek son günü kaydırırdı.
      expect(span.length, 30);
      expect(span.lastDay, DateTime(2026, 3, 19));
    });

    test('gün sayısı sabit yazılmaz, sayılır', () {
      // Sabit otuz yazılsaydı yirmi dokuz günlük bir Ramazan'da son kutu
      // bayramın birinci gününe denk gelirdi.
      final span = ramadanSpanFor(
        DateTime(2026, 3, 10),
        calendar: const _ShortRamadanCalendar(),
      )!;
      expect(span.length, 29);
      expect(span.firstDay, _ShortRamadanCalendar.first);
      expect(span.lastDay, DateTime(2026, 3, 29));
    });

    test('her günü hicri takvimle uyuşur', () {
      const calendar = IslamicCalendar();
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      for (var day = 1; day <= span.length; day++) {
        final hijri = calendar.hijri(span.dateOf(day));
        expect(hijri.month, 9, reason: '$day. gün Ramazan dışında.');
        expect(hijri.day, day);
      }
      // Sınırlar: bir önceki ve bir sonraki gün Ramazan olmamalı.
      expect(
        calendar.hijri(span.firstDay.subtract(const Duration(days: 1))).month,
        isNot(9),
      );
      expect(
        calendar.hijri(span.lastDay.add(const Duration(days: 1))).month,
        isNot(9),
      );
    });

    test('bayramdan sonra da en son Ramazan bulunur', () {
      // Tutulmayan günlere asıl bayramdan sonra bakılır.
      final span = ramadanSpanFor(DateTime(2026, 4, 15))!;
      expect(span.hijriYear, 1447);
      expect(span.firstDay, ramadanFirst);
    });

    test('tarih düzeltmesi Ramazan\'ı kaydırır', () {
      // Kullanıcı resmî ilana göre bir gün kaydırabiliyor; kayıt ekranı da
      // aynı günleri göstermeli, yoksa kutular bildirimlerle uyuşmaz.
      final shifted = ramadanSpanFor(
        DateTime(2026, 3, 1),
        calendar: const IslamicCalendar(dayOffset: 1),
      )!;
      expect(shifted.firstDay, ramadanFirst.subtract(const Duration(days: 1)));
    });
  });

  group('kayıt', () {
    test('tutuldu ve tutulmadı sayılır', () {
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      var log = FastingLog(span: span);
      expect(log.unmarkedCount, 30);

      log = log.withDay(1, const FastingEntry(FastingOutcome.fasted));
      log = log.withDay(
        2,
        const FastingEntry(FastingOutcome.missed, reason: FastingReason.travel),
      );

      expect(log.fastedCount, 1);
      expect(log.missedCount, 1);
      expect(log.unmarkedCount, 28);
      expect(log.entryOf(2)?.reason, FastingReason.travel);
    });

    test('işaret kaldırılabilir', () {
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      final log = FastingLog(span: span)
          .withDay(3, const FastingEntry(FastingOutcome.fasted))
          .withDay(3, null);
      expect(log.entryOf(3), isNull);
      expect(log.fastedCount, 0);
    });

    test('gelecek gün işaretlenemez', () {
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      final today = span.dateOf(5);
      expect(fastingDayIsMarkable(span, 5, today), isTrue);
      expect(fastingDayIsMarkable(span, 4, today), isTrue);
      expect(
        fastingDayIsMarkable(span, 6, today),
        isFalse,
        reason: 'Tutulmamış bir orucu kaydetmek kaydı anlamsız kılar.',
      );
      expect(fastingDayIsMarkable(span, 31, today), isFalse);
      expect(fastingDayIsMarkable(span, 0, today), isFalse);
    });

    test('yazılıp okunan kayıt aynı kalır', () {
      for (final entry in [
        const FastingEntry(FastingOutcome.fasted),
        const FastingEntry(
          FastingOutcome.missed,
          reason: FastingReason.illness,
        ),
        const FastingEntry(FastingOutcome.missed),
      ]) {
        expect(FastingEntry.decode(entry.encode()), entry);
      }
      // Bozuk ya da eski biçimli değer kayıt sayılmaz.
      expect(FastingEntry.decode(null), isNull);
      expect(FastingEntry.decode(''), isNull);
      expect(FastingEntry.decode('yok'), isNull);
      expect(
        FastingEntry.decode('missed:bilinmeyen'),
        const FastingEntry(FastingOutcome.missed),
      );
    });

    test('depo hicri yıla göre saklar', () async {
      // Anahtar miladi tarih olsaydı kullanıcı tarih düzeltmesini
      // değiştirdiğinde kayıtlar bir gün kayardı.
      final storage = _MemoryStorage();
      final span = ramadanSpanFor(DateTime(2026, 3, 1))!;
      final repository = FastingRepository(storage);

      await repository.saveDay(
        span,
        7,
        const FastingEntry(FastingOutcome.fasted),
      );
      expect(storage.values['dini.fasting.1447.7'], 'fasted');

      final log = await repository.load(span);
      expect(log.entryOf(7)?.outcome, FastingOutcome.fasted);
      expect(log.fastedCount, 1);

      await repository.saveDay(span, 7, null);
      expect(storage.values.containsKey('dini.fasting.1447.7'), isFalse);
    });
  });

  group('ekran', () {
    testWidgets('otuz kutu çizilir ve bir gün işaretlenir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 3, 1, 12)),
      );
      await tester.pumpAndSettle();

      expect(find.text('30'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutuldu').last);
      await tester.pumpAndSettle();

      expect(
        storage.values['dini.fasting.1447.3'],
        'fasted',
        reason: 'İşaretleme kaydedilmedi.',
      );
      expect(find.textContaining('1 gün tutuldu'), findsOneWidget);
    });

    testWidgets('sebep kaydedilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 3, 1, 12)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yolculuk'));
      await tester.pumpAndSettle();

      expect(storage.values['dini.fasting.1447.2'], 'missed:travel');
    });

    testWidgets('gelecek gün işaretlenmez, uyarı çıkar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      // Ramazan'ın üçüncü günündeyiz; onuncu gün henüz gelmedi.
      await tester.pumpWidget(
        _app(storage: storage, now: DateTime(2026, 2, 20, 12)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('işaretlenemez'),
        findsOneWidget,
        reason: 'Gelecek gün sessizce yutulmamalı.',
      );
      expect(storage.values, isEmpty);
    });

    test('hangi tarihte olursa olsun bir Ramazan bulunur', () {
      // Arama penceresi bir hicri yıldan uzun olmalı; kısa kalsaydı yılın
      // bazı günlerinde ekran boş açılırdı.
      var date = DateTime(2026, 1, 1);
      while (date.isBefore(DateTime(2027, 1, 1))) {
        final span = ramadanSpanFor(date);
        expect(span, isNotNull, reason: '$date için Ramazan bulunamadı.');
        expect(
          span!.firstDay.isAfter(date),
          isFalse,
          reason: 'Bulunan Ramazan gelecekte; geriye bakılmalı.',
        );
        date = date.add(const Duration(days: 7));
      }
    });

    testWidgets('Ramazan bulunamazsa kutu yerine ileti çıkar', (tester) async {
      // Bu dal bir savunmadır: takvim ya da düzeltme beklenmedik bir değer
      // verirse ekran boş kutularla değil, anlaşılır bir iletiyle açılmalı.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(_MemoryStorage()),
            clockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
            ramadanSpanProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            locale: Locale('tr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: FastingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizations(const Locale('tr')).text('fasting.empty')),
        findsOneWidget,
      );
      expect(find.text('30'), findsNothing);
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde dar ekranda taşmaz', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(
            storage: _MemoryStorage(),
            now: DateTime(2026, 3, 1, 12),
            languageCode: language,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppLocalizations(Locale(language)).text('fasting.title')),
          findsOneWidget,
        );
      });
    }

    testWidgets('Arapça sağdan sola çizilir', (tester) async {
      await tester.pumpWidget(
        _app(
          storage: _MemoryStorage(),
          now: DateTime(2026, 3, 1, 12),
          languageCode: 'ar',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(FastingPage))),
        TextDirection.rtl,
      );
    });
  });
}
