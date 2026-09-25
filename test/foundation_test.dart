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
  testWidgets('settings has no premium entry in the first store release', (
    tester,
  ) async {
    // İlk App Store sürümünde satın alma yok: her şey ücretsiz. Premium
    // satırı açık kalsaydı App Review satın almayı dener, ürünler hazır
    // olmadığı için reddederdi.
    await tester.pumpWidget(
      ProviderScope(child: DiniApp(router: createRouter())),
    );
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsNothing);
    final router = createRouter(initialLocation: '/premium');
    expect(
      router.configuration.findMatch(Uri.parse('/premium')).isEmpty,
      isTrue,
    );
  });
  test('localization provider has a default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localeProvider), const Locale('tr'));
  });
}
