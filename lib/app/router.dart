import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../core/localization/app_localizations.dart';
import '../features/prayer_times/presentation/providers.dart';
import '../features/prayer_times/presentation/settings_controller.dart';
import '../features/prayer_times/domain/timezone_service.dart';
import '../features/prayer_times/domain/prayer_settings.dart';
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
import '../features/prayer_times/presentation/imsakiye_page.dart';
import '../features/tasbih/presentation/tasbih_page.dart';
import '../features/notifications/presentation/notification_settings_page.dart';
import '../features/notifications/data/flutter_local_notification_service.dart';
import '../features/notifications/data/notification_scheduler.dart';
import '../features/widgets/data/widget_preferences_repository.dart';
import '../features/widgets/domain/widget_snapshot.dart';
import '../features/premium/presentation/premium_page.dart';
import '../features/quran/presentation/quran_coming_soon_page.dart';
import '../features/info/diyanet_flow.dart';
import '../features/audio/presentation/opening_takbir.dart';
import '../features/worship/presentation/worship_hub_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) {
        final l10n = context.l10n;
        final onHome = shell.currentIndex == 0;
        return Scaffold(
          extendBody: onHome,
          body: shell,
          bottomNavigationBar: NavigationBarTheme(
            data: onHome
                ? NavigationBarThemeData(
                    backgroundColor: const Color(0xF20A2425),
                    indicatorColor: const Color(0x40FFD88A),
                    iconTheme: WidgetStateProperty.resolveWith(
                      (states) => IconThemeData(
                        color: states.contains(WidgetState.selected)
                            ? const Color(0xFFFFD88A)
                            : const Color(0xFFDCE7E4),
                      ),
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => TextStyle(
                        color: states.contains(WidgetState.selected)
                            ? const Color(0xFFFFD88A)
                            : const Color(0xFFDCE7E4),
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const NavigationBarThemeData(),
            child: NavigationBar(
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
              builder: (_, _) => const QuranComingSoonPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/worship',
              builder: (_, _) => const WorshipHubPage(),
            ),
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
    GoRoute(path: '/imsakiye', builder: (_, _) => const ImsakiyePage()),
    GoRoute(path: '/tasbih', builder: (_, _) => const TasbihPage()),
    GoRoute(
      path: '/tracker',
      builder: (_, _) => const WorshipHubPage(initialIndex: 0),
    ),
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
    final topBreathingRoom = (viewport.height * .52)
        .clamp(380.0, 500.0)
        .toDouble();
    final remaining = l10n.text('home.remaining', {
      'hours': next.remaining.inHours,
      'minutes': next.remaining.inMinutes.remainder(60),
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: MosqueScene(
              state: scene,
              height: viewport.height,
              borderRadius: BorderRadius.zero,
              showShadow: false,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8C000000),
                  Color(0x12000000),
                  Color(0x70020D0E),
                  Color(0xD9082021),
                ],
                stops: [0, .22, .56, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
              children: [
                Text(
                  l10n.text('home.greeting'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 14, color: Color(0xCC000000))],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${settings.location.city ?? l10n.text('home.selectedLocation')} · ${now.day} ${l10n.month(now.month)} ${now.year}',
                  style: const TextStyle(
                    color: Color(0xFFF7F3E9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 12, color: Color(0xE0000000))],
                  ),
                ),
                SizedBox(height: topBreathingRoom),
                _NextPrayerPanel(
                  icon: _prayerIcon(next.next!),
                  title: l10n.text('home.nextPrayer'),
                  prayerAndRemaining: '${label(next.next!)} · $remaining',
                  time: fmt(next.nextTime),
                ),
                const SizedBox(height: 12),
                _GlassPanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _GlassTag(
                            icon: Icons.calendar_today_outlined,
                            label: l10n.text('home.hijri', {
                              'date': hijri.label,
                            }),
                          ),
                          if (scene.friday)
                            _GlassTag(
                              icon: Icons.star_outline,
                              label: l10n.text('home.friday'),
                            ),
                          if (scene.ramadan)
                            _GlassTag(
                              icon: Icons.nightlight_outlined,
                              label: l10n.text('home.ramadan'),
                            ),
                        ],
                      ),
                      if (scene.ramadan) ...[
                        const SizedBox(height: 12),
                        Text(
                          _ramadanMessage(now, times, fmt, l10n),
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickAction(
                            icon: Icons.explore_outlined,
                            label: l10n.text('home.qibla'),
                            onPressed: () => context.push('/qibla'),
                          ),
                          _QuickAction(
                            icon: Icons.touch_app_outlined,
                            label: l10n.text('home.tasbih'),
                            onPressed: () => context.push('/tasbih'),
                          ),
                          _QuickAction(
                            icon: Icons.check_circle_outline,
                            label: l10n.text('home.tracker'),
                            onPressed: () => context.push('/tracker'),
                          ),
                          _QuickAction(
                            icon: Icons.calendar_month_outlined,
                            label: l10n.text('home.calendar'),
                            onPressed: () => context.go('/calendar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassPanel(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l10n.text('home.todayTimes'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...Prayer.values.where((p) => p != Prayer.sunrise).map((
                        p,
                      ) {
                        final isCurrent = next.current == p;
                        final isNext = next.next == p;
                        return _PrayerTimeRow(
                          icon: _prayerIcon(p),
                          label: label(p),
                          time: fmt(times.times[p]!),
                          badge: isCurrent
                              ? l10n.text('home.now')
                              : isNext
                              ? l10n.text('home.next')
                              : null,
                          highlighted: isNext,
                        );
                      }),
                      const Divider(color: Color(0x35FFFFFF), height: 10),
                      _PrayerTimeRow(
                        icon: Icons.wb_sunny_outlined,
                        label: l10n.text('home.sunrise'),
                        time: fmt(times.times[Prayer.sunrise]!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                    glass: true,
                    onFavoriteChanged: (value) =>
                        contentRepository.setFavorite(daily.id, value),
                  ),
                ),
              ],
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

class _NextPrayerPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String prayerAndRemaining;
  final String time;

  const _NextPrayerPanel({
    required this.icon,
    required this.title,
    required this.prayerAndRemaining,
    required this.time,
  });

  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0x28FFFFFF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFFFD88A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFC9DDD8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                prayerAndRemaining,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: const TextStyle(
            color: Color(0xFFFFD88A),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 15, 16, 15),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xC20A2425),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0x45FFFFFF)),
      boxShadow: const [
        BoxShadow(
          blurRadius: 22,
          offset: Offset(0, 8),
          color: Color(0x3D000000),
        ),
      ],
    ),
    child: child,
  );
}

class _GlassTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x20FFFFFF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFD88A)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0x14000000),
      side: const BorderSide(color: Color(0x5CFFFFFF)),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18, color: const Color(0xFFFFD88A)),
    label: Text(label),
  );
}

class _PrayerTimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final String? badge;
  final bool highlighted;

  const _PrayerTimeRow({
    required this.icon,
    required this.label,
    required this.time,
    this.badge,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: highlighted ? const Color(0x2BFFD88A) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: highlighted
              ? const Color(0xFFFFD88A)
              : const Color(0xFFDCE7E4),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (badge != null)
                Text(
                  badge!,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: TextStyle(
            color: highlighted ? const Color(0xFFFFD88A) : Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
            // Dar ekran ve büyük yazı ölçeğinde yatay taşmayı önler.
            isExpanded: true,
            initialValue: settings.method,
            decoration: InputDecoration(
              labelText: l10n.text('settings.calculation'),
            ),
            items: PrayerCalculationMethod.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (m) {
              if (m != null) {
                _saveSettings(ref, settings.copyWith(method: m));
              }
            },
          ),
          DropdownButtonFormField<AsrMethod>(
            isExpanded: true,
            initialValue: settings.asrMethod,
            decoration: InputDecoration(
              labelText: l10n.text('settings.asrMethod'),
            ),
            items: AsrMethod.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.name, overflow: TextOverflow.ellipsis),
                  ),
                )
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
          const OpeningTakbirSettingTile(),
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
    await reschedulePrayerNotifications(
      storage: ref.read(localStorageProvider),
      settings: value,
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
        body: 'Ek cami temaları, gelişmiş widget tasarımları ve ileri istatistikler.',
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

class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Page({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
        children: children,
      ),
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
