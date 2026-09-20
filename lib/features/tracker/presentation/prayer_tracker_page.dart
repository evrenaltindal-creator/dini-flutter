import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../data/exemption_repository.dart';
import '../data/prayer_tracker_repository.dart';
import '../domain/prayer_tracker.dart';
import '../domain/streak.dart';
import 'streak_view.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import '../../../shared/models/domain.dart';

/// Isı haritası ve seri için okunan geçmiş.
///
/// [heatmapWeeks] hafta artı ilk haftanın başındaki boşluk kadar gün okunur;
/// daha azı haritanın ilk sütununu eksik bırakır.
final trackerHistoryProvider =
    FutureProvider.family<List<PrayerTrackerDay>, DateTime>((ref, today) {
      final repository = LocalPrayerTrackerRepository(
        ref.watch(localStorageProvider),
      );
      return repository.recent(today, days: heatmapWeeks * 7 + 7);
    });

/// Muaf günler: o günlerde namaz kılınmaz, seri bozulmaz.
final exemptionsProvider = FutureProvider.family<Set<DateTime>, DateTime>((
  ref,
  today,
) {
  final repository = ExemptionRepository(ref.watch(localStorageProvider));
  return repository.recent(today, days: heatmapWeeks * 7 + 7);
});

class PrayerTrackerPage extends StatelessWidget {
  const PrayerTrackerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('tracker.title'))),
    body: const SafeArea(child: PrayerTrackerView()),
  );
}

class PrayerTrackerView extends ConsumerStatefulWidget {
  const PrayerTrackerView({super.key});

  @override
  ConsumerState<PrayerTrackerView> createState() => _PrayerTrackerViewState();
}

class _PrayerTrackerViewState extends ConsumerState<PrayerTrackerView> {
  late final LocalPrayerTrackerRepository repository;
  PrayerTrackerDay? day;

  /// Yüklenmiş verinin ait olduğu gün. Tarih değişince yeniden yüklenir.
  DateTime? _loadedFor;

  @override
  void initState() {
    super.initState();
    repository = LocalPrayerTrackerRepository(ref.read(localStorageProvider));
  }

  /// Takip, cihazın saat dilimini değil, namaz vakitlerinin bağlı olduğu
  /// konumun yerel tarihini kullanır — ekrandaki gizlilik notu da bunu söyler.
  /// Her çizimde yeniden hesaplanır; böylece uygulama açık kalıp gece yarısı
  /// geçilse bile kayıt bir önceki güne yazılmaz.
  DateTime _effectiveDate() {
    final times = ref.watch(prayerTimesProvider);
    return TimezoneService.inLocation(
      times.timezoneId ?? 'Europe/Istanbul',
      ref.watch(clockProvider)(),
    );
  }

  Future<void> _load(DateTime date) async {
    final value = await repository.load(date);
    if (mounted) setState(() => day = value);
  }

  @override
  Widget build(BuildContext context) {
    final now = _effectiveDate();
    final today = DateUtils.dateOnly(now);
    if (_loadedFor != today) {
      _loadedFor = today;
      _load(now);
    }
    final current = day;
    if (current == null || !DateUtils.isSameDay(current.date, today)) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: current.completedCount / trackedPrayers.length,
                        strokeWidth: 7,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      Center(child: Text('${current.completedCount}/5')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.text('tracker.today'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.text('tracker.completed', {
                          'completed': current.completedCount,
                          'total': trackedPrayers.length,
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: trackedPrayers.map((prayer) {
              final checked = current.isCompleted(prayer);
              return CheckboxListTile.adaptive(
                secondary: Icon(_icon(prayer)),
                title: Text(context.l10n.prayer(prayer.name)),
                value: checked,
                onChanged: (value) async {
                  final next = current.toggle(prayer);
                  setState(() => day = next);
                  await repository.save(next);
                  // Seri ve ısı haritası bu kayda bakar; tazelenmezse
                  // işaretleme ekranda karşılık bulmaz.
                  ref.invalidate(trackerHistoryProvider(today));
                },
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        ref
            .watch(exemptionsProvider(today))
            .when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (exempt) => Card(
                child: SwitchListTile.adaptive(
                  secondary: const Icon(Icons.event_busy_outlined),
                  title: Text(context.l10n.text('tracker.exemptToday')),
                  subtitle: Text(context.l10n.text('tracker.exemptNote')),
                  value: exempt.contains(today),
                  onChanged: (value) async {
                    await ExemptionRepository(ref.read(localStorageProvider))
                        .setExempt(today, value);
                    ref.invalidate(exemptionsProvider(today));
                  },
                ),
              ),
            ),
        ref
            .watch(trackerHistoryProvider(today))
            .when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (history) {
                final exempt =
                    ref.watch(exemptionsProvider(today)).value ??
                    const <DateTime>{};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreakCard(
                      summary: streakOf(history, today: today, exempt: exempt),
                      // Muaf günde "bugünü tamamla" demek yanlış olurdu.
                      todayComplete:
                          trackerDayIsComplete(current) ||
                          exempt.contains(today),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.text('tracker.heatmap'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    HeatmapView(
                      weeks: heatmapOf(history, today: today, exempt: exempt),
                    ),
                  ],
                );
              },
            ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history_toggle_off_outlined),
            title: Text(context.l10n.text('qada.open')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/qada'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.text('tracker.privacy'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    return content;
  }

  IconData _icon(Prayer p) => switch (p) {
    Prayer.fajr => Icons.wb_twilight,
    Prayer.dhuhr => Icons.wb_sunny,
    Prayer.asr => Icons.sunny,
    Prayer.maghrib => Icons.wb_twilight,
    Prayer.isha => Icons.nightlight_round,
    Prayer.sunrise => Icons.wb_sunny_outlined,
  };
}
