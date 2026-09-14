import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/tasbih/data/tasbih_repository.dart';
import 'package:dini_flutter/features/tasbih/domain/tasbih.dart';
import 'package:dini_flutter/features/tasbih/presentation/tasbih_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

Widget _app(LocalStorage storage) => ProviderScope(
  overrides: [localStorageProvider.overrideWithValue(storage)],
  child: MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const TasbihPage(),
  ),
);

void main() {
  testWidgets('reaching the target records one history entry, not one per '
      'extra tap', (tester) async {
    final storage = _MemoryStorage();
    final repository = LocalTasbihRepository(storage);
    // Hedefin bir altından başla ki birkaç dokunuşla hedef geçilsin.
    await repository.save(
      TasbihSession(
        dhikrId: defaultDhikr.first.id,
        count: 32,
        target: 33,
        startedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    // 33'e ulaş, sonra dört kez daha say.
    final increase = find.byTooltip('Bir artır');
    for (var tap = 0; tap < 5; tap++) {
      await tester.tap(increase);
      await tester.pumpAndSettle();
    }

    final history = await repository.history();
    expect(
      history,
      hasLength(1),
      reason:
          'Hedefe ulaşmak tek bir kayıt bırakmalı. ${history.length} kayıt '
          'var: hedefi geçen her dokunuş geçmişe yeniden yazılıyor.',
    );
    expect(history.single.count, 33);
  });

  testWidgets('history shows a readable date, not a raw DateTime', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final repository = LocalTasbihRepository(storage);
    await repository.save(
      TasbihSession(
        dhikrId: defaultDhikr.first.id,
        count: 32,
        target: 33,
        startedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bir artır'));
    await tester.pumpAndSettle();

    // Ham DateTime çıktısı mikrosaniye taşır ve tarihi ISO biçiminde yazar.
    expect(
      find.textContaining(RegExp(r'\d{4}-\d{2}-\d{2}')),
      findsNothing,
      reason: 'Geçmişte ham ISO tarih görünüyor; okunur biçim bekleniyor.',
    );
    expect(find.textContaining('33 · '), findsOneWidget);
  });
}
