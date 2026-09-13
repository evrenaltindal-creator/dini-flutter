import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/tracker/data/prayer_tracker_repository.dart';
import 'package:dini_flutter/features/tracker/presentation/prayer_tracker_page.dart';
import 'package:dini_flutter/shared/models/domain.dart';
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

PrayerSettings _settingsIn(String timezoneId) => PrayerSettings(
  location: LocationPreference(
    city: 'Test',
    latitude: 0,
    longitude: 0,
    timezoneId: timezoneId,
  ),
);

/// Takip ekranını verilen saat diliminde çizer, sabah namazını işaretler ve
/// hangi tarih anahtarına yazıldığını döndürür.
Future<String> _toggleFajrIn(WidgetTester tester, String timezoneId) async {
  final storage = _MemoryStorage();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        effectivePrayerSettingsProvider.overrideWithValue(
          _settingsIn(timezoneId),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Her koşu taze bir State almalı; aksi halde ikinci çizim önceki
        // koşunun işaretini kaldırır ve hiçbir şey yazılmaz.
        home: Scaffold(body: PrayerTrackerView(key: ValueKey(timezoneId))),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(CheckboxListTile).first);
  await tester.pumpAndSettle();

  final written = storage.values.keys
      .where((key) => key.startsWith(LocalPrayerTrackerRepository.prefix))
      .toList();
  expect(written, hasLength(1), reason: 'Tek bir gün anahtarı beklenir.');
  return written.single;
}

void main() {
  setUpAll(TimezoneService.initialize);

  testWidgets('tracker records against the prayer location date, not the '
      'device date', (tester) async {
    // Bu iki saat dilimi arasında 25 saat vardır, bu yüzden yerel tarihleri
    // günün hangi anında olursa olsun farklıdır. Ekran cihazın saatini
    // kullansaydı iki koşu da aynı anahtara yazardı ve bu test düşerdi.
    final farEast = await _toggleFajrIn(tester, 'Pacific/Kiritimati');
    final farWest = await _toggleFajrIn(tester, 'Pacific/Niue');

    expect(
      farEast,
      isNot(farWest),
      reason:
          'Takip, namaz konumunun yerel tarihine yazmalıdır. Aynı anahtara '
          'yazılması cihaz saatinin kullanıldığını gösterir.',
    );
  });

  testWidgets('the written key matches the selected timezone calendar day', (
    tester,
  ) async {
    const timezoneId = 'Pacific/Kiritimati';
    final key = await _toggleFajrIn(tester, timezoneId);
    final expected = TimezoneService.inLocation(timezoneId, DateTime.now());
    final expectedKey =
        '${LocalPrayerTrackerRepository.prefix}'
        '${expected.year.toString().padLeft(4, '0')}-'
        '${expected.month.toString().padLeft(2, '0')}-'
        '${expected.day.toString().padLeft(2, '0')}.${Prayer.fajr.name}';

    expect(key, expectedKey);
  });
}
