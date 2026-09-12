import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
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
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Kuran',
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              label: 'İbadet',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Takvim',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quran',
              builder: (_, _) => const PlaceholderPage(title: 'Kuran'),
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
    String label(Prayer p) => p.name[0].toUpperCase() + p.name.substring(1);
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final viewport = MediaQuery.sizeOf(context);
    final sceneHeight = viewport.width <= 340
        ? 420.0
        : (viewport.height * .68).clamp(520.0, 680.0).toDouble();
    final remaining =
        '${next.remaining.inHours} sa ${next.remaining.inMinutes.remainder(60)} dk';
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
                    const Text(
                      'Huzurlu bir gün',
                      style: TextStyle(
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
                      '${settings.location.city ?? 'Seçili konum'} · ${now.day} ${_month(now.month)} ${now.year}',
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
                            const Text(
                              'Sıradaki namaz',
                              style: TextStyle(
                                color: Color(0xFFC9DDD8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${label(next.next!)} · $remaining kaldı',
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
                label: Text('Hicri ${hijri.label}'),
              ),
              if (scene.friday)
                const Chip(
                  avatar: Icon(Icons.star, size: 16),
                  label: Text('Cuma'),
                ),
              if (scene.ramadan)
                const Chip(
                  avatar: Icon(Icons.nightlight, size: 16),
                  label: Text('Ramazan'),
                ),
            ],
          ),
          if (scene.ramadan)
            _Card(title: 'Ramazan', body: _ramadanMessage(now, times, fmt)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/qibla'),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Kıble'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/tasbih'),
                icon: const Icon(Icons.touch_app_outlined),
                label: const Text('Tesbih'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/tracker'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Namaz takibi'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Takvim'),
              ),
            ],
          ),
          Text(
            'Bugünün vakitleri',
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
                          const Text(
                            'ŞİMDİ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        if (isNext)
                          const Text(
                            'SIRADA',
                            style: TextStyle(
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
            title: const Text('Güneş doğuşu · namaz vakti değildir'),
            trailing: Text(fmt(times.times[Prayer.sunrise]!)),
          ),
          FutureBuilder<bool>(
            future: contentRepository.isFavorite(daily.id),
            builder: (context, snapshot) => DailyContentCard(
              title: daily is VerseContent
                  ? 'Günün ayeti'
                  : daily is HadithContent
                  ? 'Günün hadisi'
                  : 'Günün duası',
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
  ) {
    final fajr = times.times[Prayer.fajr]!;
    final maghrib = times.times[Prayer.maghrib]!;
    if (now.isBefore(fajr)) {
      return 'Sahur sonu: ${fmt(fajr)} · seçili hesaplama yöntemindeki Fajr vakti';
    }
    if (now.isBefore(maghrib)) {
      final remaining = maghrib.difference(now);
      return 'İftara ${remaining.inHours} sa ${remaining.inMinutes.remainder(60)} dk · ${fmt(maghrib)}';
    }
    return 'İftar vakti: ${fmt(maghrib)}';
  }

  String _month(int m) => const [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ][m];
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
    final async = ref.watch(prayerSettingsProvider);
    final showLocation = ref.watch(widgetLocationVisibilityProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _Page(
        title: 'Ayarlar',
        children: [
          const Text(
            'Ayarlar yüklenemedi. Güvenli varsayılanlar kullanılabilir.',
          ),
          _Tile('Bildirimler', onTap: () => context.push('/notifications')),
          _Tile(
            'Diyanet’e Soru Sor',
            onTap: () async {
              await DiyanetFlow.openQuestionFlow();
            },
          ),
          _Tile('Hakkında ve kaynaklar', onTap: () => context.push('/about')),
          _Tile('Premium', onTap: () => context.push('/premium')),
          _Tile('Gizlilik Merkezi', onTap: () => context.push('/privacy')),
        ],
      ),
      data: (settings) => _Page(
        title: 'Ayarlar',
        children: [
          DropdownButtonFormField<PrayerCalculationMethod>(
            initialValue: settings.method,
            decoration: const InputDecoration(labelText: 'Hesaplama yöntemi'),
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
            decoration: const InputDecoration(labelText: 'İkindi yöntemi'),
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
            title: const Text('24 saat biçimi'),
            value: settings.use24Hour,
            onChanged: (v) =>
                _saveSettings(ref, settings.copyWith(use24Hour: v)),
          ),
          _Tile(
            'Tema',
            onTap: () =>
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
          ),
          _Tile(
            'Dil',
            onTap: () =>
                ref.read(localeProvider.notifier).state = const Locale('en'),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hicri tarih offline tabular hesaplama ile gösterilir; yerel ay gözlemi ve resmi ilanlarla bir gün farklılık gösterebilir.',
              ),
            ),
          ),
          showLocation.when(
            data: (value) => SwitchListTile(
              title: const Text('Widget’ta konum adını göster'),
              subtitle: const Text(
                'Kapalıyken prayer verileri gösterilir, şehir adı paylaşılmaz.',
              ),
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
                const ListTile(title: Text('Widget privacy yükleniyor…')),
            error: (_, _) => const ListTile(
              title: Text('Widget privacy varsayılan olarak kapalı.'),
            ),
          ),
          _Tile('Bildirimler', onTap: () => context.push('/notifications')),
          _Tile(
            'Diyanet’e Soru Sor',
            onTap: () async {
              await DiyanetFlow.openQuestionFlow();
            },
          ),
          _Tile('Hakkında ve kaynaklar', onTap: () => context.push('/about')),
          _Tile('Premium', onTap: () => context.push('/premium')),
          _Tile('Gizlilik Merkezi', onTap: () => context.push('/privacy')),
        ],
      ),
    );
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
    title: 'Gizlilik Merkezi',
    children: [
      const Text(
        'Namaz vakitleri ve konum kullanımı cihazda yereldir. Namaz takibi, tesbih, favoriler ve bildirim planlaması cihazda tutulur. Widget snapshot’ı yalnızca işletim sistemi uzantısıyla paylaşılır. Satın alma işlemleri Apple/Google mağaza altyapısı üzerinden yürür; mağazaların transaction verilerini almadığını iddia etmeyiz. Custom backend, reklam takibi ve analytics yoktur.',
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Tüm yerel veriler silinsin mi?'),
              content: const Text(
                'Ayarlar, takip geçmişi, tesbih durumu, favoriler, bildirim tercihleri ve widget snapshot’ı silinir. Bundled dini içerikler korunur.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sil'),
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
              const SnackBar(
                content: Text(
                  'Yerel veriler silindi. Güvenli varsayılanlar kullanılacak.',
                ),
              ),
            );
          }
        },
        child: const Text('Tüm yerel verileri sil'),
      ),
    ],
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Hakkında ve kaynaklar',
    children: const [
      Text('Sürüm 1.0.0+1'),
      SizedBox(height: 12),
      Text(
        'Namaz vakitleri offline yerel hesaplama ile üretilir. Hicri tarihler tabular hesaplamadır; yerel ay gözlemi ve resmi ilanlarla farklılık gösterebilir.',
      ),
      SizedBox(height: 12),
      Text(
        'Günlük ayet, hadis ve dua içerikleri bundled kaynak metadatasıyla gelir. Satın almalar Apple App Store veya Google Play altyapısında işlenir; local entitlement cache mağaza doğrulamasının kaynağı değildir.',
      ),
      SizedBox(height: 12),
      Text(
        'Diyanet soru akışı resmi dış servisi tarayıcıda açmayı amaçlar. Güncel resmi URL release öncesi ayrıca doğrulanmalıdır; uygulama Diyanet değildir ve dini hüküm vermez.',
      ),
    ],
  );
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({required this.title, super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: title,
    children: [
      Text(
        '$title foundation ekranı hazır; işlevsel feature sonraki adımda eklenecek.',
      ),
    ],
  );
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
