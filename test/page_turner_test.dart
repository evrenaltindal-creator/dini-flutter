import 'package:dini_flutter/features/quran/presentation/page_turner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı isteği: "Sayfaları da çevirelim" — normal bir kitap gibi sola.
void main() {
  late List<int> changes;

  Future<void> open(WidgetTester tester, {int initial = 0}) async {
    changes = [];
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Önceki açılışın durumu (sayfa numarası) taşınmasın.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageTurner(
            itemCount: 3,
            initialPage: initial,
            onPageChanged: changes.add,
            itemBuilder: (_, i) => ColoredBox(
              color: Colors.white,
              child: Center(child: Text('Sayfa ${i + 1}')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sola çekince sonraki sayfa gelir', (tester) async {
    await open(tester);
    expect(find.text('Sayfa 1'), findsOneWidget);
    await tester.drag(find.byType(PageTurner), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 2'), findsOneWidget);
    expect(find.text('Sayfa 1'), findsNothing);
    expect(changes, [1]);
  });

  testWidgets('az çekip bırakınca sayfa geri düşer', (tester) async {
    await open(tester);
    final gesture = await tester.startGesture(const Offset(300, 350));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    // Çevrilirken iki sayfa da ekranda: üstte kalkan, altta sonraki.
    expect(find.byKey(PageTurner.turningKey), findsOneWidget);
    expect(find.text('Sayfa 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 1'), findsOneWidget);
    expect(find.byKey(PageTurner.turningKey), findsNothing);
    expect(changes, isEmpty);
  });

  testWidgets('hızlı fırlatınca kısa mesafede de çevrilir', (tester) async {
    await open(tester);
    await tester.fling(find.byType(PageTurner), const Offset(-60, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 2'), findsOneWidget);
  });

  testWidgets('sağa çekince önceki sayfa geri gelir', (tester) async {
    await open(tester, initial: 2);
    await tester.drag(find.byType(PageTurner), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 2'), findsOneWidget);
    expect(changes, [1]);
  });

  testWidgets('kenara dokunmak çevirir, ortası çevirmez', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(200, 350));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 1'), findsOneWidget);
    await tester.tapAt(const Offset(380, 350));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 2'), findsOneWidget);
    await tester.tapAt(const Offset(20, 350));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 1'), findsOneWidget);
    expect(changes, [1, 0]);
  });

  testWidgets('kitabın başından geri, sonundan ileri gidilmez', (tester) async {
    await open(tester);
    await tester.drag(find.byType(PageTurner), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 1'), findsOneWidget);

    await open(tester, initial: 2);
    await tester.drag(find.byType(PageTurner), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 3'), findsOneWidget);
    expect(changes, isEmpty);
  });
}
