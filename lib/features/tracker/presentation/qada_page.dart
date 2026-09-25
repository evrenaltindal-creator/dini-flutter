import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../data/qada_repository.dart';
import '../domain/prayer_tracker.dart';
import '../domain/qada.dart';

final qadaRepositoryProvider = Provider(
  (ref) => QadaRepository(ref.watch(localStorageProvider)),
);

final qadaLogProvider = FutureProvider<QadaLog>(
  (ref) => ref.watch(qadaRepositoryProvider).load(),
);

/// Kaza namazlarının sayacı.
///
/// Uygulama kaç kaza borcu olduğunu hesaplamaz; sayıyı kullanıcı girer,
/// kıldıkça düşer. Hesap ve hüküm için ekran Diyanet'e yönlendirir.
class QadaPage extends ConsumerWidget {
  const QadaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(qadaLogProvider);

    return BackdropScaffold(
      title: l10n.text('qada.title'),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text(l10n.text('settings.loadError'))),
          data: (log) => _Counter(log: log),
        ),
      ),
    );
  }
}

class _Counter extends ConsumerWidget {
  final QadaLog log;

  const _Counter({required this.log});

  Future<void> _save(WidgetRef ref, QadaLog next) async {
    await ref.read(qadaRepositoryProvider).save(next);
    ref.invalidate(qadaLogProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.isEmpty
                      ? l10n.text('qada.none')
                      : l10n.text('qada.total', {'count': log.total}),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.text('qada.add'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                // Biriken kaza gün ya da yıl olarak hatırlanır; beş vakti tek
                // tek girmek yerine gün olarak eklenebilmeli.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final days in qadaDayChoices)
                      OutlinedButton(
                        onPressed: () => _save(ref, log.addDays(days)),
                        child: Text(l10n.text('qada.addDays', {'count': days})),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final prayer in trackedPrayers)
          Card(
            child: ListTile(
              title: Text(l10n.prayer(prayer.name)),
              subtitle: Text(
                l10n.text('qada.remaining', {'count': log.countOf(prayer)}),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.text('qada.markOne'),
                    // Kaza kalmadıysa düşürülecek bir şey yok.
                    onPressed: log.countOf(prayer) == 0
                        ? null
                        : () => _save(
                            ref,
                            log.withPrayer(prayer, log.countOf(prayer) - 1),
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: l10n.text('qada.add'),
                    onPressed: () => _save(
                      ref,
                      log.withPrayer(prayer, log.countOf(prayer) + 1),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          l10n.text('qada.notice'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
