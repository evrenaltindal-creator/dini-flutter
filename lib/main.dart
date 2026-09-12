import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/audio/presentation/opening_takbir.dart';
import 'features/prayer_times/presentation/settings_controller.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final localeProvider = StateProvider<Locale>((ref) => const Locale('tr'));
const localePreferenceKey = 'dini.locale';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString(localePreferenceKey);
  final initialLocale =
      AppLocalizations.supportedLocales.any(
        (locale) => locale.languageCode == savedLanguage,
      )
      ? Locale(savedLanguage!)
      : const Locale('tr');
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localeProvider.overrideWith((ref) => initialLocale),
      ],
      child: const DiniApp(),
    ),
  );
}

class DiniApp extends ConsumerWidget {
  const DiniApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => context.l10n.text('appTitle'),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    locale: ref.watch(localeProvider),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: appRouter,
    builder: (context, child) =>
        OpeningTakbirGate(child: child ?? const SizedBox.shrink()),
  );
}
