import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../../prayer_times/presentation/providers.dart';
import '../data/fasting_repository.dart';
import '../domain/fasting_log.dart';

final fastingRepositoryProvider = Provider(
  (ref) => FastingRepository(ref.watch(localStorageProvider)),
);

/// İçinde bulunulan ya da en son geçen Ramazan.
///
/// Bayramdan sonra da gerekir: tutulmayan günlere asıl o zaman bakılır.
final ramadanSpanProvider = Provider<RamadanSpan?>(
  (ref) => ramadanSpanFor(
    ref.watch(clockProvider)(),
    calendar: ref.watch(effectivePrayerSettingsProvider).calendar,
  ),
);

final fastingLogProvider = FutureProvider<FastingLog?>((ref) async {
  final span = ref.watch(ramadanSpanProvider);
  if (span == null) return null;
  return ref.watch(fastingRepositoryProvider).load(span);
});

/// Ramazan'ın günlerini kutu kutu gösteren oruç kaydı.
///
/// Kayıt kullanıcınındır: uygulama tutulmayan bir orucun kazasına ya da
/// fidyesine karar vermez, yalnızca kaydı tutar ve hüküm için Diyanet'e
/// yönlendirir.
class FastingPage extends ConsumerWidget {
  const FastingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(fastingLogProvider);

    return BackdropScaffold(
      title: l10n.text('fasting.title'),
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
              : _Log(log: log),
        ),
      ),
    );
  }
}

class _Log extends ConsumerWidget {
  final FastingLog log;

  const _Log({required this.log});

  Future<void> _edit(BuildContext context, WidgetRef ref, int day) async {
    final today = ref.read(clockProvider)();
    if (!fastingDayIsMarkable(log.span, day, today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('fasting.future'))),
      );
      return;
    }
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DaySheet(day: day, current: log.entryOf(day)),
    );
    // Sayfa kapatıldıysa hiçbir şey değişmez; kaydı silen yalnızca
    // "işareti kaldır"dır.
    if (result == null) return;
    await ref
        .read(fastingRepositoryProvider)
        .saveDay(log.span, day, result.entry);
    ref.invalidate(fastingLogProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(clockProvider)();

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.text('fasting.summary', {
                    'fasted': log.fastedCount,
                    'missed': log.missedCount,
                  }),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (log.unmarkedCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.text('fasting.remaining', {
                      'count': log.unmarkedCount,
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            for (var day = 1; day <= log.span.length; day++)
              _DayBox(
                day: day,
                entry: log.entryOf(day),
                markable: fastingDayIsMarkable(log.span, day, today),
                onTap: () => _edit(context, ref, day),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('fasting.notice'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tek bir günün kutusu.
class _DayBox extends StatelessWidget {
  final int day;
  final FastingEntry? entry;
  final bool markable;
  final VoidCallback onTap;

  const _DayBox({
    required this.day,
    required this.entry,
    required this.markable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (entry?.outcome) {
      FastingOutcome.fasted => (scheme.primary, scheme.onPrimary),
      FastingOutcome.missed => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      null => (Colors.transparent, scheme.onSurface),
    };
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: [
        l10n.text('fasting.dayLabel', {'day': day}),
        if (entry?.outcome == FastingOutcome.fasted)
          l10n.text('fasting.fasted')
        else if (entry?.outcome == FastingOutcome.missed)
          l10n.text('fasting.missed'),
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          // Gelecek günler soluktur: işaretlenemeyeceği dokunmadan
          // anlaşılmalı.
          opacity: markable ? 1 : .4,
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry != null)
                  Icon(
                    entry!.outcome == FastingOutcome.fasted
                        ? Icons.check
                        : Icons.remove,
                    size: 16,
                    color: foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayfanın kapatılmasıyla "işareti kaldır"ı ayırt eden sonuç.
///
/// İkisi de null dönseydi kullanıcı sayfayı kapattığında kayıt silinirdi.
class _SheetResult {
  final FastingEntry? entry;

  const _SheetResult(this.entry);
}

class _DaySheet extends StatelessWidget {
  final int day;
  final FastingEntry? current;

  const _DaySheet({required this.day, required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
        children: [
          ListTile(
            title: Text(
              l10n.text('fasting.dayLabel', {'day': day}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.text('fasting.fasted')),
            selected: current?.outcome == FastingOutcome.fasted,
            onTap: () => Navigator.pop(
              context,
              const _SheetResult(FastingEntry(FastingOutcome.fasted)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              l10n.text('fasting.missed'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(l10n.text('fasting.reasonTitle')),
          ),
          for (final reason in FastingReason.values)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(l10n.text('fasting.reason.${reason.name}')),
              selected:
                  current?.outcome == FastingOutcome.missed &&
                  current?.reason == reason,
              onTap: () => Navigator.pop(
                context,
                _SheetResult(
                  FastingEntry(FastingOutcome.missed, reason: reason),
                ),
              ),
            ),
          if (current != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backspace_outlined),
              title: Text(l10n.text('fasting.clearDay')),
              onTap: () => Navigator.pop(context, const _SheetResult(null)),
            ),
          ],
        ],
      ),
    );
  }
}
