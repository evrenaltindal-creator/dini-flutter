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

const _localizationDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiniStartup(loadPreferences: SharedPreferences.getInstance));
}

class DiniStartup extends StatefulWidget {
  const DiniStartup({required this.loadPreferences, super.key});

  final Future<SharedPreferences> Function() loadPreferences;

  @override
  State<DiniStartup> createState() => _DiniStartupState();
}

typedef _StartupSettings = ({
  SharedPreferences prefs,
  Locale locale,
  bool onboarded,
});

class _DiniStartupState extends State<DiniStartup> {
  late Future<_StartupSettings> _startup = _loadSettings();
  GoRouter? _router;

  Future<_StartupSettings> _loadSettings() async {
    try {
      final prefs = await widget.loadPreferences().timeout(
        const Duration(seconds: 10),
      );
      final storage = SharedPreferencesStorage(prefs);
      final onboarded = await OnboardingRepository(storage).isCompleted();
      final savedLanguage = prefs.getString(localePreferenceKey);
      final locale = AppLocalizations.supportedLocales.firstWhere(
        (locale) => locale.languageCode == savedLanguage,
        orElse: () => const Locale('tr'),
      );
      // Refresh the scheduling window without blocking startup.
      if (mounted) unawaited(_rescheduleNotifications(storage));
      return (prefs: prefs, locale: locale, onboarded: onboarded);
    } catch (error, stack) {
      debugPrint('Namaz Yolu startup settings failed: ${error.runtimeType}');
      debugPrintStack(stackTrace: stack, maxFrames: 8);
      rethrow;
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_StartupSettings>(
    future: _startup,
    builder: (context, snapshot) {
      final settings = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          settings != null) {
        final router = _router ??= createRouter(
          initialLocation: settings.onboarded ? '/' : '/onboarding',
        );
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(settings.prefs),
            localeProvider.overrideWith((ref) => settings.locale),
          ],
          child: DiniApp(router: router),
        );
      }

      final failed =
          snapshot.connectionState == ConnectionState.done && snapshot.hasError;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.text('appTitle'),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (failed) ...[
                        Text(
                          context.l10n.text('startup.error'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() {
                            _startup = _loadSettings();
                          }),
                          child: Text(context.l10n.text('startup.retry')),
                        ),
                      ] else
                        CircularProgressIndicator(
                          semanticsLabel: context.l10n.text('startup.loading'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
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
    localizationsDelegates: _localizationDelegates,
    routerConfig: router,
    builder: (context, child) =>
        OpeningTakbirGate(child: child ?? const SizedBox.shrink()),
  );
}
