import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/calendar/presentation/calendar_page.dart';
import 'package:dini_flutter/features/premium/presentation/premium_page.dart';
import 'package:dini_flutter/features/tasbih/presentation/tasbih_page.dart';
import 'package:dini_flutter/features/tracker/presentation/prayer_tracker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// İbadet merkezi ve kıble dışında kalan ekranların dar ekran, üç dil ve
/// büyük yazı ölçeğinde çizilebildiğini doğrular. Bu ekranların hiçbirinde
/// daha önce widget testi yoktu; ibadet merkezinde tam bu koşullarda ekran
/// dışına taşan bir sekme bulunmuştu.
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

/// Test edilen ekranlar. Yeni bir ekran eklendiğinde buraya da eklenmelidir.
final _screens = <String, Widget Function()>{
  'tasbih': () => const TasbihPage(),
  // CalendarPage kendi Scaffold'unu kurmaz; uygulamada router kabuğunun
  // Scaffold'u içinde çizilir, test de aynı şekilde sarmalar.
  'calendar': () => const Scaffold(body: CalendarPage()),
  'settings': () => const SettingsPage(),
  'privacy': () => const PrivacyPage(),
  'about': () => const AboutPage(),
  'tracker': () => const PrayerTrackerPage(),
  'premium': () => const PremiumStorePage(),
};

Future<void> _pump(
  WidgetTester tester,
  Widget Function() build, {
  required double width,
  String languageCode = 'tr',
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      build(),
      languageCode: languageCode,
      textScale: textScale,
      width: width,
    ),
  );
  // Ekranlar yerel depodan yükleniyor; birkaç kare bekle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  _screens.forEach((name, build) {
    group(name, () {
      for (final width in [320.0, 430.0]) {
        testWidgets('renders at ${width.toInt()}dp', (tester) async {
          await _pump(tester, build, width: width);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('renders in English on a narrow screen', (tester) async {
        await _pump(tester, build, width: 320, languageCode: 'en');
        expect(tester.takeException(), isNull);
      });

      testWidgets('survives the largest accessibility text scale', (
        tester,
      ) async {
        // iOS ve Android'in en büyük erişilebilirlik ölçeğine yakın bir uç
        // değer. Takvim hücreleri ve açılır listeler burada taşıyordu.
        await _pump(tester, build, width: 320, textScale: 2);
        expect(tester.takeException(), isNull);
      });

      testWidgets('survives Arabic right-to-left with large text', (
        tester,
      ) async {
        await _pump(
          tester,
          build,
          width: 320,
          languageCode: 'ar',
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          TextDirection.rtl,
        );
      });
    });
  });
}
