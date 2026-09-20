import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/main.dart';

void main() {
  testWidgets('application starts and home renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: DiniApp(router: createRouter())),
    );
    expect(find.text('Huzurlu bir gün'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
  testWidgets('settings routes to premium and privacy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: DiniApp(router: createRouter())),
    );
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();
    expect(find.text('Namaz Yolu Premium'), findsOneWidget);
  });
  test('theme and localization providers have defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(localeProvider), const Locale('tr'));
  });
}
