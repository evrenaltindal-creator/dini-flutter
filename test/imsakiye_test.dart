import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/prayer_times/domain/monthly_timetable.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/imsakiye_page.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ankara = Coordinates(39.9334, 32.8597);
const _istanbul = Coordinates(41.0082, 28.9784);
const _timezone = 'Europe/Istanbul';

Widget _app({String languageCode = 'tr', double textScale = 1}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: ProviderScope(
    child: MaterialApp(
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ImsakiyePage(),
    ),
  ),
);

void main() {
  setUpAll(TimezoneService.initialize);

  group('monthlyTimetable', () {
    test('ayın her günü için bir satır üretir', () {
      for (final month in [
        DateTime(2026),
        DateTime(2026, 2),
        DateTime(2026, 4),
        DateTime(2026, 12),
      ]) {
        final expected = DateTime(month.year, month.month + 1, 0).day;
        expect(
          monthlyTimetable(
            month: month,
            coordinates: _istanbul,
            timezoneId: _timezone,
          ).days,
          hasLength(expected),
          reason: '${month.month}. ay $expected gün sürer.',
        );
      }
    });

    test('artık yılın şubatı 29 gündür', () {
      // 2028 artık yıldır; 29 Şubat düşerse kullanıcı o günü hiç göremez.
      expect(
        monthlyTimetable(
          month: DateTime(2028, 2),
          coordinates: _istanbul,
          timezoneId: _timezone,
        ).days,
        hasLength(29),
      );
      expect(
        monthlyTimetable(
          month: DateTime(2026, 2),
          coordinates: _istanbul,
          timezoneId: _timezone,
        ).days,
        hasLength(28),
      );
    });

    test('satırlar gün gün sıralıdır ve doğru tarihi taşır', () {
      final table = monthlyTimetable(
        month: DateTime(2026, 9),
        coordinates: _ankara,
        timezoneId: _timezone,
      );
      for (var index = 0; index < table.days.length; index++) {
        expect(table.days[index].date, DateTime(2026, 9, index + 1));
      }
    });

    test('ayın günü gerçekten farklı vakitler verir', () {
      // Ay boyunca tek bir günün sonucu tekrarlanırsa çizelge yanlıştır.
      final table = monthlyTimetable(
        month: DateTime(2026, 9),
        coordinates: _ankara,
        timezoneId: _timezone,
      );
      final sunrises = table.days
          .map((day) => day.times[Prayer.sunrise]!.minute)
          .toSet();
      expect(
        sunrises.length,
        greaterThan(5),
        reason: 'Eylül boyunca güneş neredeyse hiç kaymıyor görünüyor.',
      );
    });

    test('her satır tek gün hesabıyla birebir aynıdır', () {
      // Çizelge kendi hesabını yapmamalı; motorla aynı sonucu vermeli.
      // İki taraf da varsayılanlarıyla çağrılır: varsayılanlar birbirinden
      // ayrılırsa çizelge ekrandakinden farklı vakitler gösterir. Bu test
      // motorun varsayılan mezhebi ayarlardan farklı kaldığı için düştü.
      const calculator = LocalPrayerTimesCalculator();
      final table = monthlyTimetable(
        month: DateTime(2026, 9),
        coordinates: _ankara,
        timezoneId: _timezone,
      );
      for (var day = 1; day <= table.days.length; day++) {
        final single = calculator.calculate(
          DateTime(2026, 9, day),
          _ankara,
          timezoneId: _timezone,
        );
        for (final prayer in Prayer.values) {
          expect(
            table.days[day - 1].times[prayer],
            single.times[prayer],
            reason: '$day Eylül ${prayer.name} çizelgede farklı çıkıyor.',
          );
        }
      }
    });

    test('yaz saati geçişinde bile vakitler sıralı kalır', () {
      // Avrupa'da saat geçişi mart sonundadır; geçiş günü sıra bozulursa
      // tabloda ters satırlar görünür.
      final table = monthlyTimetable(
        month: DateTime(2026, 3),
        coordinates: const Coordinates(52.52, 13.405),
        timezoneId: 'Europe/Berlin',
      );
      const order = [
        Prayer.fajr,
        Prayer.sunrise,
        Prayer.dhuhr,
        Prayer.asr,
        Prayer.maghrib,
        Prayer.isha,
      ];
      for (final day in table.days) {
        for (var i = 1; i < order.length; i++) {
          expect(
            day.times[order[i]]!.isAfter(day.times[order[i - 1]]!),
            isTrue,
            reason: '${day.date}: ${order[i].name} sırası bozuk.',
          );
        }
      }
    });

    test('forDay ay dışındaki tarihe null döner', () {
      final table = monthlyTimetable(
        month: DateTime(2026, 9),
        coordinates: _ankara,
        timezoneId: _timezone,
      );
      expect(table.forDay(DateTime(2026, 9, 16)), isNotNull);
      expect(table.forDay(DateTime(2026, 10, 1)), isNull);
      expect(table.forDay(DateTime(2025, 9, 16)), isNull);
    });
  });

  group('İmsakiye ekranı', () {
    for (final language in ['tr', 'en', 'ar']) {
      for (final width in [320.0, 430.0]) {
        testWidgets('${width.toInt()}dp genişlikte $language dilinde çizilir', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(_app(languageCode: language, textScale: 1.3));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason:
                'İmsakiye ${width.toInt()}dp genişlikte $language dilinde '
                'taştı. Yedi sütun dar ekranda sığmıyor olabilir.',
          );
          // Yedi başlık ve en az bir gün satırı çizilmeli.
          expect(find.byType(ListView), findsOneWidget);
        });
      }
    }

    testWidgets('Arapça düzeni sağdan sola kalır', (tester) async {
      await tester.pumpWidget(_app(languageCode: 'ar'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(ImsakiyePage))),
        TextDirection.rtl,
      );
    });

    testWidgets('içinde bulunulan ayla açılır ve ay değiştirilebilir', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final l10n = const AppLocalizations(Locale('tr'));
      expect(
        find.text('${l10n.month(now.month)} ${now.year}'),
        findsOneWidget,
        reason: 'Ekran içinde bulunulan ayla açılmalı.',
      );

      await tester.tap(find.byTooltip(l10n.text('calendar.nextMonth')));
      await tester.pumpAndSettle();

      final next = DateTime(now.year, now.month + 1);
      expect(
        find.text('${l10n.month(next.month)} ${next.year}'),
        findsOneWidget,
        reason: 'İleri düğmesi sonraki aya geçmeli.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('yalnızca bugünün satırı vurgulanır', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Bugünün satırı kalın yazılır; ay içinde tam bir tane olmalı.
      bool isHighlighted(Text text) =>
          text.style?.fontWeight == FontWeight.w700;
      final rows = tester
          .widgetList<Text>(find.byType(Text))
          .where(isHighlighted)
          .length;
      expect(
        rows,
        7,
        reason:
            'Bugünün satırında gün numarası ve altı vakit vurgulanmalı; '
            '$rows vurgulu hücre bulundu.',
      );

      // Başka bir aya geçildiğinde vurgulanan satır kalmamalı.
      await tester.tap(
        find.byTooltip(
          const AppLocalizations(Locale('tr')).text('calendar.nextMonth'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Text>(find.byType(Text)).where(isHighlighted),
        isEmpty,
        reason: 'Gelecek ayda "bugün" satırı olamaz.',
      );
    });

    testWidgets('saatler sıfır dolgulu ve okunur biçimde', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 5:03 değil 05:03 olmalı; hizasız saatler tabloda okunmaz.
      expect(find.textContaining(RegExp(r'^\d:\d\d$')), findsNothing);
      expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsWidgets);
    });
  });
}
