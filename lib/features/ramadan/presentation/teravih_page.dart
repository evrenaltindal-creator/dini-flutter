import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/domain.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import '../data/teravih_repository.dart';
import '../domain/ramadan_night.dart';
import '../domain/teravih.dart';
import 'fasting_page.dart';

final teravihRepositoryProvider = Provider(
  (ref) => TeravihRepository(ref.watch(localStorageProvider)),
);

/// Bu gece Ramazan'ın kaçıncı gecesi? Ramazan gecesi değilse null.
///
/// Akşam ezanı okunduysa gece ertesi güne aittir; yatsıdan sonra kılınan
/// teravih o geceye yazılmalı, bir önceki güne değil.
final teravihNightProvider = Provider<int?>((ref) {
  final times = ref.watch(prayerTimesProvider);
  // Saat kullanıcının saat dilimine çevrilmeli: ham yerel saatle karşılaştırma
  // cihazın dilimine göre geceyi bir gün kaydırır.
  final now = TimezoneService.inLocation(
    times.timezoneId ?? 'Europe/Istanbul',
    ref.watch(clockProvider)(),
  );
  final maghrib = times.times[Prayer.maghrib];
  return ramadanNightOf(
    now,
    afterMaghrib: maghrib != null && !now.isBefore(maghrib),
    calendar: ref.watch(effectivePrayerSettingsProvider).calendar,
  );
});

final teravihLogProvider = FutureProvider<TeravihLog?>((ref) async {
  final span = ref.watch(ramadanSpanProvider);
  if (span == null) return null;
  return ref.watch(teravihRepositoryProvider).load(span);
});

/// Gecelik teravih sayacı ve Ramazan boyunca tutulan kayıt.
class TeravihPage extends ConsumerWidget {
  const TeravihPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(teravihLogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('teravih.title'))),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text(l10n.text('settings.loadError'))),
          data: (log) => log == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(24),
                    child: Text(
                      l10n.text('fasting.empty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _Counter(log: log),
        ),
      ),
    );
  }
}

class _Counter extends ConsumerWidget {
  final TeravihLog log;

  const _Counter({required this.log});

  Future<void> _setNight(WidgetRef ref, int night, int value) async {
    await ref.read(teravihRepositoryProvider).saveNight(log.span, night, value);
    ref.invalidate(teravihLogProvider);
  }

  Future<void> _setTarget(WidgetRef ref, int target) async {
    await ref.read(teravihRepositoryProvider).saveTarget(target);
    ref.invalidate(teravihLogProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final night = ref.watch(teravihNightProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: night == null
                // Ramazan gecesi değilken sayaç gösterilmez; kayıt yine de
                // görünür, çünkü geçmiş geceler burada sayılır.
                ? Text(l10n.text('teravih.outsideRamadan'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.text('teravih.tonight', {'night': night}),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.text('teravih.ofTarget', {
                          'count': log.rekatsOf(night),
                          'target': log.target,
                        }),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _setNight(
                            ref,
                            night,
                            log.rekatsOf(night) + teravihStep,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: Text(l10n.text('teravih.addSelam')),
                      ),
                      const SizedBox(height: 8),
                      // Wrap: dar ekranda iki düğme yan yana sığmıyor ve
                      // Row taşıyordu.
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: log.rekatsOf(night) == 0
                                ? null
                                : () => _setNight(
                                    ref,
                                    night,
                                    log.rekatsOf(night) - teravihStep,
                                  ),
                            icon: const Icon(Icons.undo),
                            label: Text(l10n.text('teravih.undo')),
                          ),
                          TextButton.icon(
                            onPressed: log.rekatsOf(night) == 0
                                ? null
                                : () => _setNight(ref, night, 0),
                            icon: const Icon(Icons.restart_alt),
                            label: Text(l10n.text('teravih.reset')),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('teravih.target'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final target in teravihTargetChoices)
              ChoiceChip(
                label: Text(l10n.text('teravih.rekats', {'count': target})),
                selected: log.target == target,
                onSelected: (_) => _setTarget(ref, target),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('teravih.summary', {
            'nights': log.nightsPrayed,
            'rekats': log.totalRekats,
          }),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.text('teravih.history'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            for (var index = 1; index <= log.span.length; index++)
              _NightBox(
                night: index,
                rekats: log.rekatsOf(index),
                target: log.target,
                isTonight: index == night,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('teravih.notice'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NightBox extends StatelessWidget {
  final int night, rekats, target;
  final bool isTonight;

  const _NightBox({
    required this.night,
    required this.rekats,
    required this.target,
    required this.isTonight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = rekats >= target && rekats > 0;
    final l10n = context.l10n;

    return Semantics(
      label: [
        l10n.text('teravih.tonight', {'night': night}),
        l10n.text('teravih.rekats', {'count': rekats}),
      ].join(', '),
      child: Container(
        decoration: BoxDecoration(
          color: reached
              ? scheme.primary
              : rekats > 0
              ? scheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Bu gece çerçeveyle işaretlenir: kayıtta hangi geceyi
            // doldurduğunu görmek gerekir.
            color: isTonight ? scheme.primary : scheme.outlineVariant,
            width: isTonight ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$night',
              style: TextStyle(
                color: reached ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rekats > 0)
              Text(
                '$rekats',
                style: TextStyle(
                  fontSize: 11,
                  color: reached ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
