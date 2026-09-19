import 'dart:io';

import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/data/notification_scheduler.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/data/location_service.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/data/prayer_settings_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:dini_flutter/features/prayer_times/presentation/location_page.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/prayer_times/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _FakeLocationService implements LocationService {
  final DeviceLocation? reading;
  const _FakeLocationService([this.reading]);
  @override
  Future<DeviceLocation?> automatic() async => reading;
}

/// Kurulan bildirimleri sayar: konum değişince alarmların yeniden
/// planlandığını doğrulamak için.
class _CountingService implements LocalNotificationService {
  final scheduled = <PlannedNotification>[];
  int cancels = 0;
  @override
  Future<void> cancelAll() async => cancels++;
  @override
  Future<void> initialize() async {}
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async => scheduled.add(notification);
}

/// Şehir verisi testin başında bir kez diskten okunur.
///
/// Varlığı widget testi içinde gerçek dosya okumasıyla çözmek işe yaramaz:
/// test sahte bir saat kullanır ve `pumpAndSettle` gerçek dosya okumasını
/// beklemez, yükleniyor çarkı sonsuza kadar dönerek zaman aşımına yol açar.
late final String _citiesJson;

Widget _app({
  required LocalStorage storage,
  LocationService? location,
  LocalNotificationService? notifications,
  String languageCode = 'tr',
}) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    // Ayarlar SharedPreferences üzerinden kalıcıdır; testin okuduğu yerle
    // yazdığı yer aynı olsun diye depo buradan verilir.
    prayerSettingsRepositoryProvider.overrideWithValue(
      PrayerSettingsRepository(storage),
    ),
    cityRepositoryProvider.overrideWithValue(
      CityRepository(loadAsset: (_) async => _citiesJson),
    ),
    if (location != null) locationServiceProvider.overrideWithValue(location),
    if (notifications != null)
      notificationServiceProvider.overrideWithValue(notifications),
  ],
  child: MaterialApp(
    locale: Locale(languageCode),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const LocationPage(),
  ),
);

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('şehir listesi çizilir ve aranabilir', (tester) async {
    await tester.pumpWidget(_app(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'sanliurfa');
    await tester.pumpAndSettle();

    expect(
      find.text('Şanlıurfa'),
      findsOneWidget,
      reason: 'Türkçe karaktersiz arama sonucu listede görünmüyor.',
    );
  });

  testWidgets('şehir seçmek ayarı kaydeder ve alarmları yeniden kurar', (
    tester,
  ) async {
    // Konum değişince alarmlar yeniden planlanmazsa eski şehrin vakitleriyle
    // çalmaya devam eder. Kaydetmenin tek yolu olmasının sebebi budur.
    final storage = _MemoryStorage();
    final notifications = _CountingService();
    await NotificationPreferencesRepository(storage).save(
      const NotificationPreferences(
        prayers: {Prayer.fajr: PrayerNotificationPreference(enabled: true)},
      ),
    );

    await tester.pumpWidget(
      _app(storage: storage, notifications: notifications),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'berlin');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berlin'));
    await tester.pumpAndSettle();

    final saved = await PrayerSettingsRepository(storage).load();
    expect(saved.location.city, 'Berlin');
    expect(
      saved.location.timezoneId,
      'Europe/Berlin',
      reason: 'Şehir kaydedildi ama saat dilimi İstanbul kaldı.',
    );
    expect(
      notifications.cancels,
      greaterThan(0),
      reason: 'Eski alarmlar iptal edilmeden yenileri kurulamaz.',
    );
    expect(
      notifications.scheduled,
      isNotEmpty,
      reason: 'Konum değişti ama bildirimler yeniden planlanmadı.',
    );
  });

  testWidgets('cihaz konumu en yakın şehrin dilimiyle kaydedilir', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await tester.pumpWidget(
      _app(
        storage: storage,
        location: const _FakeLocationService(
          DeviceLocation('Cihaz konumu', Coordinates(52.52, 13.41)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pumpAndSettle();

    final saved = await PrayerSettingsRepository(storage).load();
    expect(saved.location.city, 'Berlin');
    expect(saved.location.timezoneId, 'Europe/Berlin');
  });

  testWidgets('izin verilmezse anlaşılır bir mesaj çıkar, ayar değişmez', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await tester.pumpWidget(
      _app(storage: storage, location: const _FakeLocationService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pumpAndSettle();

    expect(
      find.text(
        const AppLocalizations(Locale('tr')).text('location.permissionDenied'),
      ),
      findsOneWidget,
    );
    expect(
      storage.values.containsKey(PrayerSettingsRepository.key),
      isFalse,
      reason: 'İzin yokken ayar kaydedilmemeli.',
    );
  });

  for (final language in ['tr', 'en', 'ar']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('${width.toInt()}dp $language dilinde hatasız çizilir', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(storage: _MemoryStorage(), languageCode: language),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Arapça sağdan sola kalır', (tester) async {
    await tester.pumpWidget(
      _app(storage: _MemoryStorage(), languageCode: 'ar'),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(LocationPage))),
      TextDirection.rtl,
    );
  });
}
