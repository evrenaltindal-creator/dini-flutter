import 'dart:async';

import 'package:dini_flutter/features/onboarding/presentation/onboarding_page.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the first frame before settings finish loading', (
    tester,
  ) async {
    final settings = Completer<SharedPreferences>();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      DiniStartup(loadPreferences: () => settings.future),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DiniApp), findsNothing);

    settings.complete(await SharedPreferences.getInstance());
    await tester.pump();
    await tester.pump();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final stalled in [false, true]) {
    testWidgets('settings ${stalled ? 'timeout' : 'error'} can be retried', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var attempts = 0;

      await tester.pumpWidget(
        DiniStartup(
          loadPreferences: () {
            attempts++;
            if (attempts > 1) return SharedPreferences.getInstance();
            return stalled
                ? Completer<SharedPreferences>().future
                : Future.error(MissingPluginException());
          },
        ),
      );
      if (stalled) await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(DiniApp), findsNothing);
      final retry = find.byType(FilledButton);
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(find.byType(OnboardingPage), findsOneWidget);
    });
  }
}
