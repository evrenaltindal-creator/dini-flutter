import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../domain/streak.dart';

/// Seri kartı: güncel seri, en uzun seri ve tamamlanan gün sayısı.
class StreakCard extends StatelessWidget {
  final StreakSummary summary;

  /// Bugün tamamlandı mı? Tamamlanmadıysa serinin bugünle uzayacağı söylenir;
  /// gün bitmeden "seriyi kaybettin" demek yanlış olurdu.
  final bool todayComplete;

  const StreakCard({
    required this.summary,
    required this.todayComplete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(18),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 34,
              color: summary.current > 0 ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text('tracker.streak'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.current == 0
                        ? l10n.text('tracker.streakNone')
                        : l10n.text('tracker.streakDays', {
                            'count': summary.current,
                          }),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: 4),
                  if (!todayComplete)
                    Text(
                      l10n.text('tracker.streakToday'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    l10n.text('tracker.longest', {'count': summary.longest}),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    l10n.text('tracker.completedDays', {
                      'count': summary.completedDays,
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftaları sütun sütun gösteren ısı haritası.
///
/// Sütunlar yön duyarlıdır: soldan sağa dizilir, Arapça'da sağdan sola. En
/// eski hafta başta, bugünü içeren hafta sonda durur.
class HeatmapView extends StatelessWidget {
  final List<List<HeatmapCell?>> weeks;

  const HeatmapView({required this.weeks, super.key});

  /// Testlerin haritayı bulması için.
  static const viewKey = ValueKey('tracker-heatmap');

  /// Bir hücrenin kenar uzunluğu.
  static const cellSize = 14.0;
  static const cellGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Column(
      key: viewKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dar ekranda on yedi hafta sığmaz; kaydırılabilir olmalı.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: Directionality.of(context) == TextDirection.rtl,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final week in weeks)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: cellGap),
                  child: Column(
                    children: [
                      for (final cell in week)
                        Padding(
                          padding: const EdgeInsets.only(bottom: cellGap),
                          child: _Cell(cell: cell, scheme: scheme),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Wrap: dar ekranda gösterge tek satıra sığmıyor ve Row taşıyordu.
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.text('tracker.heatmapLegendLow'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                for (final step in [0.0, .25, .5, .75, 1.0])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: HeatmapView.cellGap,
                    ),
                    child: _Swatch(intensity: step, scheme: scheme),
                  ),
                const SizedBox(width: 2),
                Text(
                  l10n.text('tracker.heatmapLegendHigh'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Swatch(intensity: 0, scheme: scheme, exempt: true),
                const SizedBox(width: 6),
                Text(
                  l10n.text('tracker.exemptLegend'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final HeatmapCell? cell;
  final ColorScheme scheme;

  const _Cell({required this.cell, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final value = cell;
    if (value == null) {
      // Gelecek gün ya da haftanın başındaki boşluk: yer tutulur, renk yok.
      return const SizedBox(
        width: HeatmapView.cellSize,
        height: HeatmapView.cellSize,
      );
    }
    final l10n = context.l10n;
    return Tooltip(
      message: value.exempt
          ? '${value.date.day}.${value.date.month} · '
                '${l10n.text('tracker.exemptLegend')}'
          : '${value.date.day}.${value.date.month} · ${value.completed}/5',
      child: _Swatch(
        intensity: value.intensity,
        scheme: scheme,
        exempt: value.exempt,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final double intensity;
  final ColorScheme scheme;

  /// Muaf gün: namaz kılınmayan gün. Boş günle aynı görünemez, çünkü eksik
  /// kalan bir şey yoktur.
  final bool exempt;

  const _Swatch({
    required this.intensity,
    required this.scheme,
    this.exempt = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: HeatmapView.cellSize,
    height: HeatmapView.cellSize,
    decoration: BoxDecoration(
      // Boş gün ile az işaretlenmiş gün ayırt edilebilmeli: boş gün yalnızca
      // çerçeveyle çizilir.
      color: exempt
          ? scheme.secondaryContainer
          : intensity == 0
          ? scheme.surfaceContainerHighest
          : scheme.primary.withValues(alpha: .25 + intensity * .75),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: exempt ? scheme.secondary : scheme.outlineVariant,
        width: exempt ? 1 : .5,
      ),
    ),
  );
}
