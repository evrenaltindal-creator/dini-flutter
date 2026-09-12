import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/qibla/presentation/qibla_page.dart';
import 'package:dini_flutter/features/worship/domain/worship_guide.dart';
import 'package:dini_flutter/features/worship/presentation/prayer_guide_view.dart';
import 'package:dini_flutter/features/worship/presentation/worship_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _widths = [320.0, 360.0, 390.0, 430.0];

Widget _app(
  Widget home, {
  String languageCode = 'tr',
  double textScale = 1,
  double width = 390,
}) => MediaQuery(
  data: MediaQueryData(
    size: Size(width, 900),
    textScaler: TextScaler.linear(textScale),
  ),
  child: ProviderScope(
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
  ),
);

/// Her sekmenin ekran içinde kaldığını ve dokunulabildiğini doğrular.
/// Sekme çubuğu taşarsa kullanıcı o sekmeyi hiç göremez; bu yüzden sadece
/// istisna olmaması yetmez, sekmenin görünür alanda olması da gerekir.
Future<void> _visitEveryTab(WidgetTester tester, double screen) async {
  final tabs = find.byType(Tab);
  expect(tabs, findsNWidgets(4));

  for (var index = 0; index < 4; index++) {
    final rect = tester.getRect(tabs.at(index));
    expect(
      rect.left,
      greaterThanOrEqualTo(-0.5),
      reason: '$index numaralı sekme sol kenardan taşıyor: $rect',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(screen + 0.5),
      reason:
          '$index numaralı sekme ekran dışında kalıyor ($rect, ekran $screen). '
          'Kullanıcı bu sekmeyi göremez.',
    );

    await tester.tap(tabs.at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.takeException(),
      isNull,
      reason: '$index numaralı ibadet sekmesi hata verdi.',
    );
  }
}

void main() {
  group('worship hub layout', () {
    for (final width in _widths) {
      testWidgets('no layout exception at ${width.toInt()}dp', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_app(const WorshipHubPage(), width: width));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        await _visitEveryTab(tester, width);
      });
    }

    testWidgets('survives a large text scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(const WorshipHubPage(), textScale: 1.5));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      await _visitEveryTab(tester, 390);
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(const WorshipHubPage(), languageCode: 'ar'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(WorshipHubPage))),
        TextDirection.rtl,
      );
      await _visitEveryTab(tester, 390);
    });

    testWidgets('English renders without exceptions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(const WorshipHubPage(), languageCode: 'en'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      await _visitEveryTab(tester, 390);
    });
  });

  group('qibla layout', () {
    for (final width in _widths) {
      testWidgets('no layout exception at ${width.toInt()}dp', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_app(const QiblaPage(), width: width));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders right-to-left in Arabic at a large text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(const QiblaPage(), languageCode: 'ar', textScale: 1.5),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(QiblaPage))),
        TextDirection.rtl,
      );
    });
  });

  group('prayer guide detail', () {
    /// Rehber görseli uzun olduğu için akış bölümü ilk ekranın altında kalır;
    /// tembel ListView onu ancak kaydırınca oluşturur.
    Future<void> scrollToFlow(WidgetTester tester) => tester.scrollUntilVisible(
      find.text('Bir rekâtın temel akışı'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    for (final width in _widths) {
      testWidgets('renders rakat flow at ${width.toInt()}dp', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(
            PrayerGuideDetailPage(guide: dailyPrayerGuides.last),
            width: width,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await scrollToFlow(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(ExpansionTile), findsWidgets);
      });
    }

    testWidgets('expanding a part reveals its rakats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(PrayerGuideDetailPage(guide: dailyPrayerGuides.first)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await scrollToFlow(tester);

      final before = tester.widgetList(find.byType(ExpansionTile)).length;
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Açılan bölüm kendi rekâtlarını iç içe açılır başlıklar olarak getirir.
      expect(
        tester.widgetList(find.byType(ExpansionTile)).length,
        greaterThan(before),
      );
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(
          PrayerGuideDetailPage(guide: dailyPrayerGuides.first),
          languageCode: 'ar',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(PrayerGuideDetailPage))),
        TextDirection.rtl,
      );
    });
  });
}
