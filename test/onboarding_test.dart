import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/notifications/data/notification_scheduler.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:dini_flutter/features/onboarding/data/system_settings.dart';
import 'package:dini_flutter/features/onboarding/domain/onboarding.dart';
import 'package:dini_flutter/features/onboarding/presentation/onboarding_page.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/data/prayer_settings_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/prayer_times/presentation/settings_controller.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
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

/// Bildirim izninin gerçekten istendiğini görmek için sayan servis.
class _CountingService implements LocalNotificationService {
  int permissionRequests = 0;
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequests++;
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async {}
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

/// Şehir verisi bir kez diskten okunur; widget testinin sahte saati gerçek
/// dosya okumasını beklemez.
late final String _citiesJson;

Widget _app({
  required LocalStorage storage,
  String initialLocation = '/onboarding',
  LocalNotificationService? notifications,
  SystemSettings? systemSettings,
  String languageCode = 'tr',
}) => ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    cityRepositoryProvider.overrideWithValue(
      CityRepository(loadAsset: (_) async => _citiesJson),
    ),
    localeProvider.overrideWith((ref) => Locale(languageCode)),
    // Ayarlar ekranı vakit ayarlarını bu depodan okur; verilmezse
    // `sharedPreferencesProvider` bulunamaz ve ekran hata dalına düşer.
    prayerSettingsRepositoryProvider.overrideWithValue(
      PrayerSettingsRepository(storage),
    ),
    if (notifications != null)
      notificationServiceProvider.overrideWithValue(notifications),
    if (systemSettings != null)
      systemSettingsProvider.overrideWithValue(systemSettings),
  ],
  // Uygulamanın kendisi kurulur: dil bağlantısı ve rota `main.dart` içinde
  // yazılıdır, testin onu taklit etmesi o bağlantıyı doğrulamaz.
  child: DiniApp(router: createRouter(initialLocation: initialLocation)),
);

/// [languageCode] dilinde bir metin anahtarının karşılığı.
String _t(String key, String languageCode) =>
    AppLocalizations(Locale(languageCode)).text(key);

/// Akışta bir adım ilerler.
Future<void> _next(WidgetTester tester, String languageCode) async {
  await tester.tap(find.text(_t('onboarding.next', languageCode)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('adım sırası', () {
    test('dil, konumun önünde gelir', () {
      // Dil seçilmeden sonraki adımların metni anlaşılmaz; konum bilinmeden
      // bildirimin hangi vakitleri haber vereceği belirsizdir.
      expect(onboardingSteps, [
        OnboardingStep.language,
        OnboardingStep.location,
        OnboardingStep.notifications,
        OnboardingStep.battery,
      ]);
    });

    test('her adımın bir sonrası var, son adımın yok', () {
      expect(
        nextOnboardingStep(OnboardingStep.language),
        OnboardingStep.location,
      );
      expect(nextOnboardingStep(OnboardingStep.battery), isNull);
      expect(isLastOnboardingStep(OnboardingStep.battery), isTrue);
      expect(isLastOnboardingStep(OnboardingStep.language), isFalse);
    });

    test('her adımın metni üç dilde de var', () {
      // `text()` bulamadığı anahtarı olduğu gibi döner; eksik çeviri ekranda
      // "onboarding.battery.body" olarak görünürdü.
      for (final language in ['tr', 'en', 'ar']) {
        for (final step in onboardingSteps) {
          for (final suffix in ['title', 'body']) {
            final key = onboardingKey(step, suffix);
            expect(
              AppLocalizations(Locale(language)).text(key),
              isNot(key),
              reason: '$key çevirisi $language dilinde yok.',
            );
          }
        }
        for (final key in [
          'onboarding.skip',
          'onboarding.next',
          'onboarding.finish',
          'onboarding.battery.unavailable',
        ]) {
          expect(AppLocalizations(Locale(language)).text(key), isNot(key));
        }
      }
    });
  });

  group('akış', () {
    testWidgets('uygulama akış tamamlanmadan ilk açılışta buraya düşer', (
      tester,
    ) async {
      await tester.pumpWidget(_app(storage: _MemoryStorage()));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text(_t('onboarding.language.title', 'tr')), findsOneWidget);
    });

    testWidgets('tamamlanmış akış ana ekrana açılır', (tester) async {
      // `main.dart` bayrağı okur ve başlangıç rotasını ona göre verir; rota
      // varsayılanı ana ekran kalmalı.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cityRepositoryProvider.overrideWithValue(
              CityRepository(loadAsset: (_) async => _citiesJson),
            ),
          ],
          child: DiniApp(router: createRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsNothing);
    });

    testWidgets('adımlar sırayla ilerler', (tester) async {
      await tester.pumpWidget(_app(storage: _MemoryStorage()));
      await tester.pumpAndSettle();

      for (final step in onboardingSteps.skip(1)) {
        await _next(tester, 'tr');
        expect(
          find.text(_t(onboardingKey(step, 'title'), 'tr')),
          findsOneWidget,
          reason: '${step.name} adımı görünmedi.',
        );
      }
      // Son adımda düğme "Başla" olur.
      expect(find.text(_t('onboarding.finish', 'tr')), findsOneWidget);
    });

    testWidgets('akış bitince bayrak yazılır ve ana ekrana geçilir', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_t('onboarding.skip', 'tr')));
      await tester.pumpAndSettle();

      expect(
        await OnboardingRepository(storage).isCompleted(),
        isTrue,
        reason: 'Bayrak yazılmazsa akış her açılışta baştan sorar.',
      );
      expect(find.byType(OnboardingPage), findsNothing);
    });

    testWidgets('seçilen dil anında uygulanır ve kaydedilir', (tester) async {
      final storage = _MemoryStorage();
      await tester.pumpWidget(_app(storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(
        find.text(_t('onboarding.language.title', 'en')),
        findsOneWidget,
        reason:
            'Dil hemen uygulanmazsa sonraki adımlar okunamayan dilde kalır.',
      );
      expect(await storage.read(localePreferenceKey), 'en');
    });

    testWidgets('bildirim adımı izni gerçekten ister', (tester) async {
      // İzin hiç istenmezse alarmlar kurulur ama kullanıcı hiçbirini görmez.
      final notifications = _CountingService();
      await tester.pumpWidget(
        _app(storage: _MemoryStorage(), notifications: notifications),
      );
      await tester.pumpAndSettle();

      await _next(tester, 'tr');
      await _next(tester, 'tr');
      await tester.tap(find.text(_t('onboarding.notifications.action', 'tr')));
      await tester.pumpAndSettle();

      expect(notifications.permissionRequests, 1);
    });

    testWidgets('pil adımı ayar sayfasını açar', (tester) async {
      final settings = _FakeSystemSettings(true);
      await tester.pumpWidget(
        _app(storage: _MemoryStorage(), systemSettings: settings),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await _next(tester, 'tr');
      }
      await tester.tap(find.text(_t('onboarding.battery.action', 'tr')));
      await tester.pumpAndSettle();

      expect(settings.calls, 1);
      expect(
        find.text(_t('onboarding.battery.unavailable', 'tr')),
        findsNothing,
      );
    });

    testWidgets('ayar sayfası açılamazsa yönlendirme metni gösterilir', (
      tester,
    ) async {
      // Üretici ayar ekranlarının intent'leri belgelenmemiştir; açılamayan bir
      // ekran çökmeye değil anlaşılır bir yönlendirmeye düşmelidir.
      final settings = _FakeSystemSettings(false);
      await tester.pumpWidget(
        _app(storage: _MemoryStorage(), systemSettings: settings),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await _next(tester, 'tr');
      }
      await tester.tap(find.text(_t('onboarding.battery.action', 'tr')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(_t('onboarding.battery.unavailable', 'tr')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('dar ekran ve üç dil', () {
    for (final language in ['tr', 'en', 'ar']) {
      testWidgets('$language dilinde 320dp\'de taşma yok', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _app(storage: _MemoryStorage(), languageCode: language),
        );
        await tester.pumpAndSettle();

        for (final step in onboardingSteps) {
          expect(
            find.text(_t(onboardingKey(step, 'title'), language)),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${step.name} adımı $language dilinde taşıyor.',
          );
          if (!isLastOnboardingStep(step)) await _next(tester, language);
        }
      });
    }

    testWidgets('Arapça akış sağdan sola çizilir', (tester) async {
      await tester.pumpWidget(
        _app(storage: _MemoryStorage(), languageCode: 'ar'),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(OnboardingPage))),
        TextDirection.rtl,
      );
    });
  });

  testWidgets('Ayarlar akışı yeniden başlatabilir', (tester) async {
    // Akış bir kez geçilince bir daha görünmez; pil rehberine ve konum
    // adımına dönmenin başka yolu kalmaz.
    final storage = _MemoryStorage();
    await OnboardingRepository(storage).markCompleted();

    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(storage: storage, initialLocation: '/settings'),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(_t('settings.rerunOnboarding', 'tr')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(_t('settings.rerunOnboarding', 'tr')));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(
      await OnboardingRepository(storage).isCompleted(),
      isFalse,
      reason: 'Bayrak sıfırlanmazsa akış sonraki açılışta yine atlanır.',
    );
  });
}
