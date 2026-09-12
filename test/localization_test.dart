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

  test('every language defines exactly the same keys', () {
    final turkish = AppLocalizations.keysFor('tr');
    final english = AppLocalizations.keysFor('en');
    final arabic = AppLocalizations.keysFor('ar');

    expect(turkish, isNotEmpty);
    expect(
      english,
      turkish,
      reason:
          'English is missing ${turkish.difference(english)} and has extra '
          '${english.difference(turkish)}. Her metin tr/en/ar icin birlikte eklenmelidir.',
    );
    expect(
      arabic,
      turkish,
      reason:
          'Arabic is missing ${turkish.difference(arabic)} and has extra '
          '${arabic.difference(turkish)}. Her metin tr/en/ar icin birlikte eklenmelidir.',
    );
  });

  test('no language leaves a key empty', () {
    for (final code in ['tr', 'en', 'ar']) {
      final localizations = AppLocalizations(Locale(code));
      for (final key in AppLocalizations.keysFor(code)) {
        expect(
          localizations.text(key).trim(),
          isNotEmpty,
          reason: '$code dilinde "$key" bos.',
        );
      }
    }
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
