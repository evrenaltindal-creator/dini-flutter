import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/onboarding/data/system_settings.dart';
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

class _FakeSystemSettings implements SystemSettings {
  final bool opens;
  int calls = 0;
  _FakeSystemSettings(this.opens);
  @override
  Future<bool> openAppSettings() async {
    calls++;
    return opens;
  }
}

Widget _app(
  _RecordingService service,
  LocalStorage storage, {
  String languageCode = 'tr',
  SystemSettings? systemSettings,
}) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    notificationServiceProvider.overrideWithValue(service),
    if (systemSettings != null)
      systemSettingsProvider.overrideWithValue(systemSettings),
  ],
  child: MaterialApp(
    locale: Locale(languageCode),
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

  group('Ramazan uyarı süreleri', () {
    /// Uzun bir yüzey kullanır ki liste tamamı oluşturulsun.
    ///
    /// `ListView` tembeldir: görünmeyen karolar hiç yaratılmaz, dolayısıyla
    /// "şu alan yok" iddiası ekranın dışındaki her şey için boş yere geçer.
    /// Bu testin ölçtüğü şey tam olarak bir alanın var olup olmadığı.
    Future<void> pumpTall(
      WidgetTester tester,
      LocalStorage storage, {
      String languageCode = 'tr',
    }) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(_RecordingService(), storage, languageCode: languageCode),
      );
      await tester.pumpAndSettle();
    }

    Finder switchTitled(String key) => find.ancestor(
      of: find.text(const AppLocalizations(Locale('tr')).text(key)),
      matching: find.byType(SwitchListTile),
    );

    testWidgets('süre seçimi yalnızca uyarı açıkken görünür', (tester) async {
      final storage = _MemoryStorage();
      await pumpTall(tester, storage);

      final label = const AppLocalizations(Locale('tr'))
          .text('notifications.suhoorMinutes');
      expect(
        find.text(label),
        findsNothing,
        reason: 'Kapalı bir uyarının süresi gösterilmemeli.',
      );

      await tester.tap(switchTitled('notifications.suhoor'));
      await tester.pumpAndSettle();

      expect(
        find.text(label),
        findsOneWidget,
        reason: 'Uyarı açıldı ama süresi seçilemiyor.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('seçilen süre kaydedilir ve yeniden planlanır', (tester) async {
      final storage = _MemoryStorage();
      // Sahur uyarısı açık ama süresi varsayılan.
      await NotificationPreferencesRepository(storage)
          .save(const NotificationPreferences(ramadanSuhoorReminder: true));

      await pumpTall(tester, storage);

      final field = find.byType(DropdownButtonFormField<int>);
      await tester.tap(field);
      await tester.pumpAndSettle();

      final l10n = const AppLocalizations(Locale('tr'));
      final ninety = l10n.text('notifications.minutesBefore', {'minutes': 90});
      await tester.tap(find.text(ninety).last);
      await tester.pumpAndSettle();

      final saved = await NotificationPreferencesRepository(storage).load();
      expect(
        saved.suhoorMinutes,
        90,
        reason: 'Seçilen süre kaydedilmedi; ekran kapanınca kaybolur.',
      );
    });

    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde dar ekranda taşmaz', (tester) async {
        final storage = _MemoryStorage();
        await NotificationPreferencesRepository(storage).save(
          const NotificationPreferences(
            ramadanSuhoorReminder: true,
            ramadanIftarReminder: true,
          ),
        );

        // Dar ekranda bütün liste tek seferde çizilir: taşma varsa görülür.
        await tester.binding.setSurfaceSize(const Size(320, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(_RecordingService(), storage, languageCode: language),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // İki süre alanı da çizilmeli.
        expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
      });
    }
  });

  testWidgets('pil rehberi bildirim ayarlarında kalıcı olarak durur', (
    tester,
  ) async {
    // İlk açılışta rehberi geçen kullanıcı için tek kalıcı yer burası.
    // Tam zamanlı alarm izni verilmiş olsa bile agresif pil yönetimi
    // bildirimi dakikalarca geciktirir.
    final settings = _FakeSystemSettings(false);
    // Uzun yüzey: tembel liste yalnızca görünen kartları kurar, rehberin
    // açılan gövdesi kısa ekranda hiç çizilmezdi.
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(_RecordingService(), _MemoryStorage(), systemSettings: settings),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bildirimler gecikmesin'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Otomatik başlatma'),
      findsOneWidget,
      reason: 'Rehber metni açılmadı.',
    );

    await tester.tap(find.text('Uygulama ayarlarını aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(settings.calls, 1);
    expect(
      find.textContaining('Ayar sayfası açılamadı'),
      findsOneWidget,
      reason: 'Açılamayan ayar ekranı sessizce yutulmamalı.',
    );
  });
}
