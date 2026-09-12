import 'package:dini_flutter/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _homeAt(double width, {double textScale = 1}) => MediaQuery(
  data: MediaQueryData(
    size: Size(width, 800),
    textScaler: TextScaler.linear(textScale),
  ),
  child: const ProviderScope(
    child: MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: HomePage()),
    ),
  ),
);

void main() {
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('home has no layout exception at ${width.toInt()}dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_homeAt(width));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Bugünün vakitleri'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Güneş doğuşu · namaz vakti değildir'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Güneş doğuşu · namaz vakti değildir'), findsOneWidget);
    });
  }

  testWidgets('home preserves core information with large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_homeAt(390, textScale: 1.4));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Huzurlu bir gün'), findsOneWidget);
    expect(find.text('Sıradaki namaz'), findsOneWidget);
  });
}
