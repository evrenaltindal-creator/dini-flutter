import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../domain/prayer_flow.dart';
import '../domain/worship_guide.dart';

class PrayerGuideView extends StatelessWidget {
  const PrayerGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
      children: [
        _IntroCard(
          icon: Icons.auto_stories_outlined,
          title: l10n.text('guide.prayerTitle'),
          body: l10n.text('guide.prayerIntro'),
        ),
        const SizedBox(height: 12),
        ...dailyPrayerGuides.map(
          (guide) => Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PrayerGuideDetailPage(guide: guide),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 12, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: const Icon(Icons.mosque_outlined),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.prayer(guide.prayer.name),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(_partSummary(context, guide.parts)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.text('guide.schoolNotice'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class PrayerGuideDetailPage extends StatelessWidget {
  final DailyPrayerGuide guide;

  const PrayerGuideDetailPage({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayer(guide.prayer.name))),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/guides/prayer_movements.png',
              fit: BoxFit.fitWidth,
              semanticLabel: l10n.text('guide.prayerImageLabel'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.text('guide.orderTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ...guide.parts.indexed.map(
            (entry) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${entry.$1 + 1}')),
                title: Text(_partLabel(context, entry.$2.kind)),
                subtitle: Text(
                  l10n.text('guide.rakatCount', {'count': entry.$2.rakats}),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.text('guide.movementsTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...prayerFlow(guide).map((part) => _PartFlowCard(flow: part)),
          const SizedBox(height: 12),
          Text(
            l10n.text('guide.recitationsTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const _RecitationSection(),
          const SizedBox(height: 12),
          _IntroCard(
            icon: Icons.info_outline,
            title: l10n.text('guide.beginnerTitle'),
            body: l10n.text('guide.beginnerEssentials'),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.text('guide.source'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;

  const _NumberedStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 15, child: Text('$number')),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    ),
  );
}

class _IntroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _IntroCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _partSummary(BuildContext context, List<PrayerPart> parts) => parts
    .map(
      (part) =>
          '${part.rakats} ${context.l10n.text('guide.rakat')} ${_partLabel(context, part.kind)}',
    )
    .join(' · ');

String _partLabel(BuildContext context, PrayerPartKind kind) => switch (kind) {
  PrayerPartKind.firstSunnah => context.l10n.text('guide.firstSunnah'),
  PrayerPartKind.fard => context.l10n.text('guide.fard'),
  PrayerPartKind.finalSunnah => context.l10n.text('guide.finalSunnah'),
  PrayerPartKind.witr => context.l10n.text('guide.witr'),
};

/// Bir namaz bölümünü rekât rekât açar.
class _PartFlowCard extends StatelessWidget {
  final PrayerPartFlow flow;

  const _PartFlowCard({required this.flow});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ExpansionTile(
        title: Text(_partLabel(context, flow.kind)),
        subtitle: Text(
          l10n.text('guide.rakatCount', {'count': flow.rakats.length}),
        ),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
        children: [
          ...flow.rakats.map(
            (rakat) => ExpansionTile(
              tilePadding: EdgeInsetsDirectional.zero,
              title: Text(
                l10n.text('guide.rakatLabel', {'index': rakat.index}),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              children: [
                for (final (index, key) in rakat.movementKeys.indexed)
                  _NumberedStep(number: index + 1, text: l10n.text(key)),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            leading: const Icon(Icons.self_improvement_outlined),
            title: Text(l10n.text('guide.finalSitting')),
            subtitle: Text(l10n.text(finalSittingKey)),
          ),
        ],
      ),
    );
  }
}

/// Okunacak metinler. Kütüphane boşken tahmini metin göstermek yerine
/// içeriğin henüz eklenmediğini açıkça söyler.
class _RecitationSection extends StatelessWidget {
  const _RecitationSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (recitationLibrary.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Text(
            l10n.text('guide.recitationsEmpty'),
            style: const TextStyle(height: 1.45),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final recitation in recitationLibrary.values)
          if (!recitation.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recitation.name.isNotEmpty)
                      Text(
                        recitation.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (recitation.arabic.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        recitation.arabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 22, height: 1.9),
                      ),
                    ],
                    if (recitation.transliteration.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.text('guide.transliteration')}: '
                        '${recitation.transliteration}',
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                    if (recitation.meaning.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.text('guide.meaning')}: ${recitation.meaning}',
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                    if (recitation.source.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        recitation.source,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
