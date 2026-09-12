import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Arabic strings are available', () {
    const english = AppLocalizations(Locale('en'));
    const arabic = AppLocalizations(Locale('ar'));

    expect(english.text('nav.home'), 'Home');
    expect(english.prayer('maghrib'), 'Maghrib');
    expect(arabic.text('nav.home'), 'الرئيسية');
    expect(arabic.prayer('maghrib'), 'المغرب');
  });

  testWidgets('Arabic locale renders the application right-to-left', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(context.l10n.text('nav.home')),
        ),
      ),
    );

    final arabicHome = find.text('الرئيسية');
    expect(arabicHome, findsOneWidget);
    expect(Directionality.of(tester.element(arabicHome)), TextDirection.rtl);
  });
}
