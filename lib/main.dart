import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/audio/presentation/opening_takbir.dart';
import 'core/storage/local_storage.dart';
import 'features/notifications/data/notification_scheduler.dart';
import 'features/prayer_times/data/prayer_settings_repository.dart';
import 'features/widgets/data/live_activity_controller.dart';
import 'features/widgets/data/widget_snapshot_builder.dart';
import 'features/watch/data/watch_schedule_builder.dart';
import 'features/prayer_times/presentation/settings_controller.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('tr'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = SharedPreferencesStorage(prefs);
  // İlk açılış akışı tamamlanmamışsa uygulama oradan başlar. Akış yazılana
  // kadar dil, konum ve bildirim izni hiç sorulmuyordu.
  final onboarded = await OnboardingRepository(storage).isCompleted();
  final savedLanguage = prefs.getString(localePreferenceKey);
  final initialLocale =
      AppLocalizations.supportedLocales.any(
        (locale) => locale.languageCode == savedLanguage,
      )
      ? Locale(savedLanguage!)
      : const Locale('tr');
  // Bildirimler yalnızca sekiz günlük bir pencere için planlanır ve daha önce
  // hiçbir yerde açılışta tazelenmiyordu. Açılışta yeniden planlamak hem bu
  // pencereyi kaydırır hem de önceki oturumda kaydedilmiş ama kurulmamış
  // alarmları devreye alır. Hata olursa uygulamanın açılışını engellemez.
  unawaited(_rescheduleNotifications(storage));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localeProvider.overrideWith((ref) => initialLocale),
      ],
      child: DiniApp(
        router: createRouter(initialLocation: onboarded ? '/' : '/onboarding'),
      ),
    ),
  );
}

Future<void> _rescheduleNotifications(LocalStorage storage) async {
  try {
    final settings = await PrayerSettingsRepository(storage).load();
    await reschedulePrayerNotifications(storage: storage, settings: settings);
    // Canlı etkinlik uygulamadan uzun yaşar; açılışta sıradaki vakte göre
    // yeniden kurulur ya da geçmişse kapatılır.
    await syncLiveActivity(
      storage: storage,
      settings: settings,
      now: DateTime.now(),
    );
    await pushWidgetSnapshot(
      storage: storage,
      settings: settings,
      now: DateTime.now(),
    );
    // Açılışta çizelge yenilenir: iki haftalık pencere her gün kayar.
    await pushWatchSchedule(
      storage: storage,
      settings: settings,
      now: DateTime.now(),
    );
  } catch (_) {
    // Bildirim eklentisi veya kayıtlı ayar olmayan ortamlarda sessiz geç.
  }
}

class DiniApp extends ConsumerWidget {
  final GoRouter router;

  const DiniApp({required this.router, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => context.l10n.text('appTitle'),
    // Uygulamanın tek bir koyu tasarımı var. Her sayfanın arkasında koyu
    // cami sahnesi durur; aydınlık tema bu zeminde kart dışında kalan her
    // yazıyı koyu-üstüne-koyu çiziyordu (17 sayfanın 12'si). Telefon
    // aydınlık kipte olsa da uygulama koyu çizilir;
    // backdrop_legibility_test.dart bunu her rotada bekçiler.
    theme: AppTheme.dark,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    // İlk açılışta seçilen dil anında uygulanmalı ki sonraki adımlar
    // yeni dilde okunsun.
    locale: ref.watch(onboardingLocaleProvider) ?? ref.watch(localeProvider),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
    builder: (context, child) =>
        OpeningTakbirGate(child: child ?? const SizedBox.shrink()),
  );
}
