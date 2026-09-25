import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/tracker/data/exemption_repository.dart';
import 'package:dini_flutter/features/tracker/data/prayer_tracker_repository.dart';
import 'package:dini_flutter/features/tracker/domain/prayer_tracker.dart';
import 'package:dini_flutter/features/tracker/domain/streak.dart';
import 'package:dini_flutter/features/tracker/presentation/prayer_tracker_page.dart';
import 'package:dini_flutter/features/tracker/presentation/streak_view.dart';
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

/// [completed] kadar vakti işaretlenmiş bir gün.
PrayerTrackerDay day(DateTime date, int completed) => PrayerTrackerDay(date, {
  for (var index = 0; index < trackedPrayers.length; index++)
    trackedPrayers[index]: index < completed,
});

final today = DateTime(2026, 9, 20);
DateTime ago(int days) => today.subtract(Duration(days: days));

Widget _app({required LocalStorage storage, String languageCode = 'tr'}) =>
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 20, 12)),
      ],
      child: MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PrayerTrackerPage(),
      ),
    );

void main() {
  setUpAll(TimezoneService.initialize);

  group('seri', () {
    test('kayıt yoksa seri yoktur', () {
      expect(streakOf(const [], today: today).current, 0);
      expect(
        streakOf([day(today, 0), day(ago(1), 0)], today: today).current,
        0,
      );
    });

    test('gün ancak beş vakitle tamamlanır', () {
      // Daha gevşek bir ölçü seriyi anlamsız kılardı.
      expect(trackerDayIsComplete(day(today, 5)), isTrue);
      expect(trackerDayIsComplete(day(today, 4)), isFalse);
      expect(
        streakOf([day(today, 4), day(ago(1), 4)], today: today).current,
        0,
      );
    });

    test('ardışık günler sayılır', () {
      final days = [
        day(today, 5),
        day(ago(1), 5),
        day(ago(2), 5),
        day(ago(3), 0),
      ];
      expect(streakOf(days, today: today).current, 3);
    });

    test('bugün boşsa seri bozulmaz', () {
      // Gün bitmeden "seriyi kaybettin" demek, sabah namazından sonra
      // uygulamayı açan herkese yanlış söylerdi.
      final days = [day(today, 2), day(ago(1), 5), day(ago(2), 5)];
      final summary = streakOf(days, today: today);
      expect(summary.current, 2);
    });

    test('dün de boşsa seri sıfırlanır', () {
      final days = [day(today, 0), day(ago(1), 0), day(ago(2), 5)];
      expect(streakOf(days, today: today).current, 0);
    });

    test('en uzun seri geçmişten bulunur', () {
      final days = [
        day(today, 5),
        day(ago(1), 0),
        day(ago(2), 5),
        day(ago(3), 5),
        day(ago(4), 5),
        day(ago(5), 5),
      ];
      final summary = streakOf(days, today: today);
      expect(summary.current, 1);
      expect(summary.longest, 4);
      expect(summary.completedDays, 5);
    });

    test('en uzun seri güncel seriden küçük olamaz', () {
      final days = [day(today, 5), day(ago(1), 5)];
      final summary = streakOf(days, today: today);
      expect(summary.longest, greaterThanOrEqualTo(summary.current));
    });

    test('sıra karışık gelse de doğru sayılır', () {
      // Liste sırasına güvenmek, deponun sırasını sessiz bir sözleşmeye
      // çevirirdi.
      final days = [day(ago(2), 5), day(today, 5), day(ago(1), 5)];
      expect(streakOf(days, today: today).current, 3);
    });
  });

  group('muafiyet', () {
    test('muaf gün seriyi bozmaz', () {
      // Namaz kılınmayan günde eksik kalan bir şey yoktur; seri o günün
      // üzerinden atlayarak devam etmeli.
      final days = [
        day(today, 5),
        day(ago(1), 0),
        day(ago(2), 0),
        day(ago(3), 5),
        day(ago(4), 5),
      ];
      expect(streakOf(days, today: today).current, 1);
      expect(
        streakOf(days, today: today, exempt: {ago(1), ago(2)}).current,
        3,
        reason: 'Muaf günler seriyi kesiyor.',
      );
    });

    test('muaf gün seriye eklenmez', () {
      final days = [day(today, 5), day(ago(1), 0), day(ago(2), 5)];
      final summary = streakOf(days, today: today, exempt: {ago(1)});
      expect(summary.current, 2, reason: 'Muaf gün seriye sayılmış.');
      expect(summary.completedDays, 2);
    });

    test('bugün muafsa seri bozulmaz', () {
      final days = [day(today, 0), day(ago(1), 5), day(ago(2), 5)];
      expect(streakOf(days, today: today, exempt: {today}).current, 2);
    });

    test('muaf gün en uzun seriyi de taşır', () {
      final days = [
        day(today, 0),
        day(ago(1), 5),
        day(ago(2), 0),
        day(ago(3), 5),
        day(ago(4), 5),
      ];
      final summary = streakOf(days, today: today, exempt: {ago(2)});
      expect(summary.longest, 3);
    });

    test('hepsi muafsa sonsuza gidilmez', () {
      // Geriye doğru arama elde veri olan en eski günde durmalı.
      final days = [day(today, 0), day(ago(1), 5)];
      final summary = streakOf(
        days,
        today: today,
        exempt: {for (var index = 0; index < 400; index++) ago(index)},
      );
      expect(summary.current, 0);
    });

    test('depo muaf günü saklar', () async {
      final storage = _MemoryStorage();
      final repository = ExemptionRepository(storage);

      await repository.setExempt(today, true);
      expect(await repository.isExempt(today), isTrue);
      expect(
        storage.values['dini.tracker.exempt.2026-09-20'],
        '1',
        reason: 'Muafiyet anahtarı namaz kaydının anahtarına karışmamalı.',
      );

      expect(await repository.recent(today, days: 3), {today});

      await repository.setExempt(today, false);
      expect(await repository.isExempt(today), isFalse);
    });

    test('muaf gün ısı haritasında ayrı görünür', () {
      // Boş gün ile muaf gün aynı renkte olamaz.
      final weeks = heatmapOf(const [], today: today, exempt: {ago(1)});
      final cells = [
        for (final week in weeks)
          for (final cell in week) ?cell,
      ];
      expect(cells.firstWhere((cell) => cell.date == ago(1)).exempt, isTrue);
      expect(cells.firstWhere((cell) => cell.date == ago(2)).exempt, isFalse);
    });
  });

  group('ısı haritası', () {
    test('her hafta yedi hücredir ve pazartesi başlar', () {
      final weeks = heatmapOf(const [], today: today);
      expect(weeks.every((week) => week.length == 7), isTrue);
      final firstDate = weeks.first.firstWhere((cell) => cell != null)!.date;
      expect(
        firstDate.weekday,
        DateTime.monday,
        reason: 'Sütunlar haftanın ortasından başlıyor.',
      );
    });

    test('bugünden sonrası boş bırakılır', () {
      // Tutulmamış bir gün ile henüz gelmemiş bir gün aynı şey değildir.
      //
      // Hafta ORTASINDA bir gün seçilmeli: haftanın son gününde son sütunda
      // zaten boş hücre kalmaz ve kontrol boşa düşer.
      final midweek = DateTime(2026, 9, 16);
      expect(midweek.weekday, DateTime.wednesday);

      final weeks = heatmapOf(const [], today: midweek);
      final lastWeek = weeks.last;
      expect(lastWeek[midweek.weekday - 1]?.date, midweek);
      expect(
        lastWeek.sublist(midweek.weekday).every((cell) => cell == null),
        isTrue,
        reason: 'Gelecek günler sıfır işaretli gün gibi çiziliyor.',
      );
      expect(
        lastWeek.where((cell) => cell == null).length,
        7 - midweek.weekday,
      );
    });

    test('işaretli günler yoğunluk verir', () {
      final weeks = heatmapOf([day(today, 5), day(ago(1), 2)], today: today);
      final cells = [
        for (final week in weeks)
          for (final cell in week) ?cell,
      ];
      final todayCell = cells.firstWhere((cell) => cell.date == today);
      final yesterday = cells.firstWhere((cell) => cell.date == ago(1));
      expect(todayCell.intensity, 1);
      expect(yesterday.intensity, closeTo(.4, .001));
      expect(cells.firstWhere((cell) => cell.date == ago(5)).intensity, 0);
    });

    test('istenen hafta sayısı kadar sütun vardır', () {
      final weeks = heatmapOf(const [], today: today, weeks: 4);
      expect(weeks.length, inInclusiveRange(4, 5));
    });
  });

  group('ekran', () {
    testWidgets('seri ve ısı haritası çizilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      final repository = LocalPrayerTrackerRepository(storage);
      // Dün ve evvelsi gün tamamlandı; bugün henüz boş.
      for (final past in [1, 2]) {
        await repository.save(day(ago(past), 5));
      }

      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();

      expect(find.byType(HeatmapView), findsOneWidget);
      expect(find.text('2 gün'), findsOneWidget);
      expect(
        find.text('Bugünü tamamlayınca seri uzar.'),
        findsOneWidget,
        reason: 'Bugün boşken seri bozulmuş gibi gösterilmemeli.',
      );
    });

    testWidgets('bugünü tamamlamak seriyi uzatır', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      final repository = LocalPrayerTrackerRepository(storage);
      await repository.save(day(ago(1), 5));

      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('1 gün'), findsOneWidget);

      for (final prayer in trackedPrayers) {
        await tester.tap(
          find.text(AppLocalizations(const Locale('tr')).prayer(prayer.name)),
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.text('2 gün'),
        findsOneWidget,
        reason: 'İşaretleme seriye yansımadı.',
      );
    });

    testWidgets('muaf işaretlemek seriyi korur', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final storage = _MemoryStorage();
      final repository = LocalPrayerTrackerRepository(storage);
      // Dün ve evvelsi tamamlandı; bugün namaz kılınmıyor.
      for (final past in [1, 2]) {
        await repository.save(day(ago(past), 5));
      }

      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('2 gün'), findsOneWidget);

      await tester.tap(find.text('Bugün namaz kılmıyorum'));
      await tester.pumpAndSettle();

      expect(
        storage.values['dini.tracker.exempt.2026-09-20'],
        '1',
        reason: 'Muafiyet kaydedilmedi.',
      );
      expect(
        find.text('Bugünü tamamlayınca seri uzar.'),
        findsNothing,
        reason: 'Muaf günde tamamlama çağrısı yapılmamalı.',
      );
      expect(find.text('2 gün'), findsOneWidget);
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde dar ekranda taşmaz', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(storage: _MemoryStorage(), languageCode: language),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HeatmapView), findsOneWidget);
      });
    }
  });
}
