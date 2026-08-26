import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dini_flutter/main.dart';

void main() {
  testWidgets('Dini foundation starts', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DiniApp()));
    expect(find.text('Huzurlu bir gün'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });
}
