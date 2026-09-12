import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../core/localization/app_localizations.dart';
import '../features/prayer_times/presentation/providers.dart';
import '../features/prayer_times/presentation/settings_controller.dart';
import '../features/prayer_times/domain/timezone_service.dart';
import '../features/prayer_times/domain/prayer_settings.dart';
import '../features/prayer_times/domain/prayer_engine.dart';
import '../shared/models/domain.dart';
import '../features/qibla/presentation/qibla_page.dart';
import '../features/home/domain/mosque_scene_state.dart';
import '../features/home/presentation/mosque_scene.dart';
import '../features/calendar/domain/islamic_calendar.dart';
import '../features/content/domain/content_repository.dart';
import '../features/content/presentation/content_card.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/storage_provider.dart';
import '../core/storage/local_data_repository.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/tracker/presentation/prayer_tracker_page.dart';
import '../features/tasbih/presentation/tasbih_page.dart';
import '../features/notifications/presentation/notification_settings_page.dart';
import '../features/notifications/data/flutter_local_notification_service.dart';
import '../features/notifications/data/notification_preferences_repository.dart';
import '../features/notifications/domain/notification_system.dart';
import '../features/widgets/data/widget_preferences_repository.dart';
import '../features/widgets/domain/widget_snapshot.dart';
import '../features/premium/presentation/premium_page.dart';
import '../features/info/diyanet_flow.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) {
        final l10n = context.l10n;
        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.text('nav.home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                label: l10n.text('nav.quran'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.mosque_outlined),
                label: l10n.text('nav.worship'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                label: l10n.text('nav.calendar'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                label: l10n.text('nav.settings'),
              ),
            ],
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quran',
              builder: (_, _) => const PlaceholderPage(titleKey: 'nav.quran'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/worship', builder: (_, _) => const TasbihPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/calendar', builder: (_, _) => const CalendarPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/premium', builder: (_, _) => const PremiumStorePage()),
    GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
    GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
    GoRoute(path: '/qibla', builder: (_, _) => const QiblaPage()),
    GoRoute(path: '/tasbih', builder: (_, _) => const TasbihPage()),
    GoRoute(path: '/tracker', builder: (_, _) => const PrayerTrackerPage()),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationSettingsPage(),
    ),
  ],
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final times = ref.watch(prayerTimesProvider);
    final next = ref.watch(nextPrayerProvider);
    final settings = ref.watch(effectivePrayerSettingsProvider);
    final now = TimezoneService.inLocation(
      times.timezoneId ?? 'Europe/Istanbul',
      DateTime.now(),
    );
    final hijri = const IslamicCalendar().hijri(now);
    final scene = const MosqueSceneStateResolver().resolve(
      now,
      times,
      friday: now.weekday == DateTime.friday,
      ramadan: hijri.month == 9,
    );
    final daily = OfflineContentRepository.dailyFor(now);
    final contentRepository = _contentRepository(ref);
    String label(Prayer p) => l10n.prayer(p.name);
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final viewport = MediaQuery.sizeOf(context);
    final sceneHeight = viewport.width <= 340
        ? 420.0
        : (viewport.height * .68).clamp(520.0, 680.0).toDouble();
    final remaining = l10n.text('home.remaining', {
      'hours': next.remaining.inHours,
      'minutes': next.remaining.inMinutes.remainder(60),
    });
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Stack(
            children: [
              RepaintBoundary(
                child: MosqueScene(state: scene, height: sceneHeight),
              ),
              Positioned(
                top: 24,
                left: 22,
                right: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text('home.greeting'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(blurRadius: 12, color: Color(0x99000000)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${settings.location.city ?? l10n.text('home.selectedLocation')} · ${now.day} ${l10n.month(now.month)} ${now.year}',
                      style: const TextStyle(
                        color: Color(0xFFF7F3E9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(blurRadius: 10, color: Color(0xB0000000)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                  decoration: BoxDecoration(
                    color: const Color(0xB20A2425),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0x55FFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 22,
                        offset: Offset(0, 8),
                        color: Color(0x40000000),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0x33FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _prayerIcon(next.next!),
                          color: const Color(0xFFFFD88A),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.text('home.nextPrayer'),
                              style: const TextStyle(
                                color: Color(0xFFC9DDD8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${label(next.next!)} · $remaining',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt(next.nextTime),
                        style: const TextStyle(
                          color: Color(0xFFFFD88A),
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(l10n.text('home.hijri', {'date': hijri.label})),
              ),
              if (scene.friday)
                Chip(
                  avatar: const Icon(Icons.star, size: 16),
                  label: Text(l10n.text('home.friday')),
                ),
              if (scene.ramadan)
                Chip(
                  avatar: const Icon(Icons.nightlight, size: 16),
                  label: Text(l10n.text('home.ramadan')),
                ),
            ],
          ),
          if (scene.ramadan)
            _Card(
              title: l10n.text('home.ramadan'),
              body: _ramadanMessage(now, times, fmt, l10n),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/qibla'),
                icon: const Icon(Icons.explore_outlined),
                label: Text(l10n.text('home.qibla')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/tasbih'),
                icon: const Icon(Icons.touch_app_outlined),
                label: Text(l10n.text('home.tasbih')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/tracker'),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(l10n.text('home.tracker')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(l10n.text('home.calendar')),
              ),
            ],
          ),
          Text(
            l10n.text('home.todayTimes'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: Prayer.values.where((p) => p != Prayer.sunrise).map((
                  p,
                ) {
                  final isCurrent = next.current == p;
                  final isNext = next.next == p;
                  return ListTile(
                    dense: true,
                    selected: isNext,
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    leading: Icon(_prayerIcon(p)),
                    title: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(label(p)),
                        if (isCurrent)
                          Text(
                            l10n.text('home.now'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        if (isNext)
                          Text(
                            l10n.text('home.next'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: Text(
                      fmt(times.times[p]!),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l10n.text('home.sunrise')),
            trailing: Text(fmt(times.times[Prayer.sunrise]!)),
          ),
          FutureBuilder<bool>(
            future: contentRepository.isFavorite(daily.id),
            builder: (context, snapshot) => DailyContentCard(
              title: daily is VerseContent
                  ? l10n.text('home.verse')
                  : daily is HadithContent
                  ? l10n.text('home.hadith')
                  : l10n.text('home.prayer'),
              content: daily,
              initiallyFavorite: snapshot.data ?? false,
              onFavoriteChanged: (value) =>
                  contentRepository.setFavorite(daily.id, value),
            ),
          ),
        ],
      ),
    );
  }

  OfflineContentRepository _contentRepository(WidgetRef ref) {
    try {
      return OfflineContentRepository(
        SharedPreferencesStorage(ref.read(sharedPreferencesProvider)),
      );
    } on StateError {
      return const OfflineContentRepository(null);
    }
  }

  String _ramadanMessage(
    DateTime now,
    PrayerTimes times,
    String Function(DateTime) fmt,
    AppLocalizations l10n,
  ) {
    final fajr = times.times[Prayer.fajr]!;
    final maghrib = times.times[Prayer.maghrib]!;
    if (now.isBefore(fajr)) {
      return l10n.text('ramadan.suhoor', {'time': fmt(fajr)});
    }
    if (now.isBefore(maghrib)) {
      final remaining = maghrib.difference(now);
      return l10n.text('ramadan.iftarRemaining', {
        'hours': remaining.inHours,
        'minutes': remaining.inMinutes.remainder(60),
        'time': fmt(maghrib),
      });
    }
    return l10n.text('ramadan.iftar', {'time': fmt(maghrib)});
  }

  IconData _prayerIcon(Prayer p) => switch (p) {
    Prayer.fajr => Icons.wb_twilight,
    Prayer.sunrise => Icons.wb_sunny_outlined,
    Prayer.dhuhr => Icons.wb_sunny,
    Prayer.asr => Icons.sunny,
    Prayer.maghrib => Icons.wb_twilight,
    Prayer.isha => Icons.nightlight_round,
  };
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(prayerSettingsProvider);
    final showLocation = ref.watch(widgetLocationVisibilityProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _Page(
        title: l10n.text('settings.title'),
        children: [
          Text(l10n.text('settings.loadError')),
          _languageSelector(context, ref),
          _Tile(
            l10n.text('settings.notifications'),
            onTap: () => context.push('/notifications'),
          ),
          _Tile(
            l10n.text('settings.askDiyanet'),
            onTap: () async {
              await DiyanetFlow.openQuestionFlow();
            },
          ),
          _Tile(
            l10n.text('settings.about'),
            onTap: () => context.push('/about'),
          ),
          _Tile(
            l10n.text('settings.premium'),
            onTap: () => context.push('/premium'),
          ),
          _Tile(
            l10n.text('settings.privacy'),
            onTap: () => context.push('/privacy'),
          ),
        ],
      ),
      data: (settings) => _Page(
        title: l10n.text('settings.title'),
        children: [
          DropdownButtonFormField<PrayerCalculationMethod>(
            initialValue: settings.method,
            decoration: InputDecoration(
              labelText: l10n.text('settings.calculation'),
            ),
            items: PrayerCalculationMethod.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (m) {
              if (m != null) {
                _saveSettings(ref, settings.copyWith(method: m));
              }
            },
          ),
          DropdownButtonFormField<AsrMethod>(
            initialValue: settings.asrMethod,
            decoration: InputDecoration(
              labelText: l10n.text('settings.asrMethod'),
            ),
            items: AsrMethod.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (m) {
              if (m != null) {
                _saveSettings(ref, settings.copyWith(asrMethod: m));
              }
            },
          ),
          SwitchListTile(
            title: Text(l10n.text('settings.clock24')),
            value: settings.use24Hour,
            onChanged: (v) =>
                _saveSettings(ref, settings.copyWith(use24Hour: v)),
          ),
          _Tile(
            l10n.text('settings.theme'),
            onTap: () =>
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
          ),
          _languageSelector(context, ref),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.text('settings.hijriNotice')),
            ),
          ),
          showLocation.when(
            data: (value) => SwitchListTile(
              title: Text(l10n.text('settings.widgetLocation')),
              subtitle: Text(l10n.text('settings.widgetLocationHint')),
              value: value,
              onChanged: (next) async {
                await WidgetPreferencesRepository(
                  ref.read(localStorageProvider),
                ).setShowLocationName(next);
                ref.invalidate(widgetLocationVisibilityProvider);
                await const WidgetSnapshotService().refresh();
              },
            ),
            loading: () =>
                ListTile(title: Text(l10n.text('settings.widgetLoading'))),
            error: (_, _) =>
                ListTile(title: Text(l10n.text('settings.widgetDefault'))),
          ),
          _Tile(
            l10n.text('settings.notifications'),
            onTap: () => context.push('/notifications'),
          ),
          _Tile(
            l10n.text('settings.askDiyanet'),
            onTap: () async {
              await DiyanetFlow.openQuestionFlow();
            },
          ),
          _Tile(
            l10n.text('settings.about'),
            onTap: () => context.push('/about'),
          ),
          _Tile(
            l10n.text('settings.premium'),
            onTap: () => context.push('/premium'),
          ),
          _Tile(
            l10n.text('settings.privacy'),
            onTap: () => context.push('/privacy'),
          ),
        ],
      ),
    );
  }

  Widget _languageSelector(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(localeProvider).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.text('settings.language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.text('settings.languageHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ar', label: Text('العربية')),
              ],
              selected: {selected},
              onSelectionChanged: (value) => _setLocale(ref, value.single),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLocale(WidgetRef ref, String languageCode) async {
    ref.read(localeProvider.notifier).state = Locale(languageCode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(localePreferenceKey, languageCode);
  }

  Future<void> _saveSettings(WidgetRef ref, PrayerSettings value) async {
    await ref.read(prayerSettingsProvider.notifier).saveSettings(value);
    await const WidgetSnapshotService().refresh();
    final storage = ref.read(localStorageProvider);
    final preferences = await NotificationPreferencesRepository(storage).load();
    final service = FlutterLocalNotificationService();
    await service.initialize();
    await PrayerNotificationCoordinator(
      service: service,
      calculator: const LocalPrayerTimesCalculator(),
    ).reschedule(
      start: TimezoneService.inLocation(
        value.location.timezoneId ?? 'Europe/Istanbul',
        DateTime.now(),
      ),
      coordinates: Coordinates(
        value.location.latitude ?? 41.0082,
        value.location.longitude ?? 28.9784,
      ),
      settings: value,
      preferences: preferences,
    );
  }
}

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Dini Premium',
    children: [
      const Text('Temel dini özellikler herkes için ücretsiz kalır.'),
      _Card(
        title: 'Premium ekleri',
        body:
            'Ek cami temaları, gelişmiş widget tasarımları ve ileri istatistikler.',
      ),
      FilledButton(
        onPressed: null,
        child: const Text('Mağaza entegrasyonu foundation aşamasında'),
      ),
    ],
  );
}

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Page(
    title: context.l10n.text('settings.privacy'),
    children: [
      Text(context.l10n.text('privacy.body')),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.text('privacy.deleteTitle')),
              content: Text(context.l10n.text('privacy.deleteBody')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.text('privacy.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.text('privacy.confirm')),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await FlutterLocalNotificationService().cancelAll();
          await LocalDataRepository(ref.read(localStorageProvider)).deleteAll();
          await const WidgetSnapshotService().clearSnapshot();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.text('privacy.deleted'))),
            );
          }
        },
        child: Text(context.l10n.text('privacy.delete')),
      ),
    ],
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: context.l10n.text('settings.about'),
    children: [
      Text(context.l10n.text('about.version')),
      const SizedBox(height: 12),
      Text(context.l10n.text('about.prayer')),
      const SizedBox(height: 12),
      Text(context.l10n.text('about.content')),
      const SizedBox(height: 12),
      Text(context.l10n.text('about.diyanet')),
    ],
  );
}

class PlaceholderPage extends StatelessWidget {
  final String titleKey;
  const PlaceholderPage({required this.titleKey, super.key});
  @override
  Widget build(BuildContext context) {
    final title = context.l10n.text(titleKey);
    return _Page(
      title: title,
      children: [
        Text(context.l10n.text('placeholder', {'title': title})),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Page({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  final String title, body;
  const _Card({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Tile(this.label, {this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
