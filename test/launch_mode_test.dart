import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/premium/domain/premium.dart';
import 'package:dini_flutter/features/premium/presentation/premium_page.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';
import 'package:dini_flutter/features/quran/presentation/quran_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quran_fixture.dart';

Widget _app(
  Widget home, {
  String languageCode = 'tr',
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
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
  group('PremiumLaunchPolicy', () {
    const launch = PremiumLaunchPolicy(everythingFree: true);
    const paid = PremiumLaunchPolicy(everythingFree: false);
    const free = PremiumEntitlement();
    const owned = PremiumEntitlement(status: EntitlementStatus.premiumLifetime);

    test('during launch everything is unlocked without a purchase', () {
      expect(launch.isUnlocked(free), isTrue);
      expect(launch.isUnlocked(owned), isTrue);
    });

    test('during launch the store is hidden', () {
      expect(launch.showsStore, isFalse);
    });

    test('once the paid period starts the gate returns', () {
      expect(paid.isUnlocked(free), isFalse);
      expect(paid.isUnlocked(owned), isTrue);
      expect(paid.showsStore, isTrue);
    });

    test('the shipped default is the free launch period', () {
      // Ücretli döneme geçiş tek bir --dart-define ile yapılır; varsayılanın
      // yanlışlıkla değişmesi kullanıcıdan ödeme istemeye başlar.
      expect(const PremiumLaunchPolicy().everythingFree, isTrue);
      expect(const PremiumLaunchPolicy().showsStore, isFalse);
    });
  });

  testWidgets('the premium screen sells nothing during the launch period', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PremiumStorePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Şu anda her şey ücretsiz'), findsOneWidget);
    // Hiçbir şey açmayan bir ürün satılmamalı.
    expect(find.text('Satın alımları geri yükle'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  group('Quran home screen', () {
    late QuranBook book;
    setUpAll(() async => book = await loadQuranBookFromDisk());

    Widget quran({String languageCode = 'tr'}) => _app(
      const QuranHomePage(),
      languageCode: languageCode,
      overrides: [quranBookProvider.overrideWith((ref) => book)],
    );

    testWidgets('lists the surahs by their Turkish names', (tester) async {
      await tester.pumpWidget(quran());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fâtiha'), findsOneWidget);
      expect(find.text('Bakara'), findsOneWidget);
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('renders in $language on a narrow screen', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(quran(languageCode: language));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps right-to-left in Arabic', (tester) async {
      await tester.pumpWidget(quran(languageCode: 'ar'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(QuranHomePage))),
        TextDirection.rtl,
      );
      expect(find.text('الفاتحة'), findsWidgets);
    });
  });
}
