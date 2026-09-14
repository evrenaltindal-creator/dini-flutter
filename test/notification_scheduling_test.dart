import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/notifications/data/notification_scheduler.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/notifications/presentation/notification_settings_page.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
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

/// Gerçek eklenti yerine ne planlandığını kaydeden sahte servis.
class _RecordingService implements LocalNotificationService {
  final List<PlannedNotification> scheduled = [];
  int cancelAllCount = 0;
  int permissionRequests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequests++;
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async => scheduled.add(notification);
}

Widget _app(_RecordingService service, LocalStorage storage) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    notificationServiceProvider.overrideWithValue(service),
  ],
  child: MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: NotificationSettingsView()),
  ),
);

void main() {
  setUpAll(TimezoneService.initialize);

  testWidgets('turning an alarm on schedules it without asking for permission '
      'first', (tester) async {
    final service = _RecordingService();
    final storage = _MemoryStorage();

    await tester.pumpWidget(_app(service, storage));
    await tester.pumpAndSettle();

    // Sabah namazı anahtarını aç. Kullanıcı izin düğmesine dokunmadı.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      service.permissionRequests,
      0,
      reason: 'Bu senaryoda izin istenmedi; planlama yine de yapılmalı.',
    );
    expect(
      service.scheduled,
      isNotEmpty,
      reason:
          'Alarm açıldı ama hiçbir bildirim kurulmadı. Planlama, kullanıcının '
          'aynı oturumda izin düğmesine basmasına bağlanmamalıdır.',
    );
  });

  testWidgets('opening the screen reschedules preferences saved earlier', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    // Önceki oturumda kaydedilmiş bir tercih: sabah alarmı açık.
    await NotificationPreferencesRepository(storage).save(
      const NotificationPreferences().copyWith(
        prayers: {
          Prayer.fajr: const PrayerNotificationPreference(enabled: true),
        },
      ),
    );

    final service = _RecordingService();
    await tester.pumpWidget(_app(service, storage));
    await tester.pumpAndSettle();

    expect(
      service.scheduled,
      isNotEmpty,
      reason:
          'Daha önce kaydedilmiş alarm, ekran açıldığında yeniden '
          'kurulmalıdır; sekiz günlük pencere başka türlü tazelenmez.',
    );
  });

  test('the shared scheduler plans without a permission call', () async {
    final service = _RecordingService();
    final storage = _MemoryStorage();
    await NotificationPreferencesRepository(storage).save(
      const NotificationPreferences().copyWith(
        prayers: {
          Prayer.maghrib: const PrayerNotificationPreference(enabled: true),
        },
      ),
    );

    await reschedulePrayerNotifications(
      storage: storage,
      settings: const PrayerSettings(),
      service: service,
    );

    expect(service.cancelAllCount, 1);
    expect(service.permissionRequests, 0);
    expect(service.scheduled, isNotEmpty);
  });
}
