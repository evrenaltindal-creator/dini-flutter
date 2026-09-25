import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/models/domain.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../domain/prayer_flow.dart';
import '../domain/worship_guide.dart';
import 'guided_prayer_page.dart';

class PrayerGuideView extends StatelessWidget {
  const PrayerGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      // Sekme kabuğunda sayfa alttaki çubuğun arkasına uzanır: listenin
      // sonu çubuğun üstüne çıkabilsin diye onun payı eklenir.
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        18,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
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
              onTap: () =>
                  context.push(PrayerGuideDetailPage.routeFor(guide.prayer)),
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

  /// Vaktin rehber sayfasının yolu. Ana ekranda bir vakte dokununca bu
  /// açılır; güneş doğuşunun rehberi yoktur, o bir namaz vakti değildir.
  static String routeFor(Prayer prayer) => '/guide/prayer/${prayer.name}';

  /// Yoldaki vakit adından rehber; bilinmeyen addan null.
  static DailyPrayerGuide? guideFor(String? name) {
    for (final guide in dailyPrayerGuides) {
      if (guide.prayer.name == name) return guide;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // BackdropScaffold: düz Scaffold temanın opak zeminini çizer ve arkadaki
    // camiyi örterdi.
    return BackdropScaffold(
      title: l10n.prayer(guide.prayer.name),
      body: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          8,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
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
          // Namaz hocası: bütün bölümleri sırayla adım adım kıldırır.
          FilledButton.icon(
            onPressed: () =>
                context.push(GuidedPrayerPage.routeFor(guide.prayer)),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l10n.text('hoca.start')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
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
                trailing: IconButton(
                  tooltip: l10n.text('hoca.startPart', {
                    'part': _partLabel(context, entry.$2.kind),
                  }),
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () => context.push(
                    GuidedPrayerPage.routeFor(guide.prayer, part: entry.$1),
                  ),
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
          // Doğrulanmış metin girilene kadar bu bölüm hiç gösterilmez:
          // kalıcı bir "yakında" kutusu göstermektense sessiz kalmak yeğdir.
          if (recitationLibrary.values.any((r) => r.isComplete)) ...[
            Text(
              l10n.text('guide.recitationsTitle'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const _RecitationSection(),
            const SizedBox(height: 12),
          ],
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

/// Okunacak metinler. Yalnızca Arapça metin, okunuş, anlam ve kaynağı
/// eksiksiz girilmiş kayıtlar çizilir; yarım veya boş kayıt gösterilmez.
class _RecitationSection extends StatelessWidget {
  const _RecitationSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final id in guideRecitationIds)
          if (recitationLibrary[id]!.isComplete)
            _RecitationCard(recitation: recitationLibrary[id]!),
      ],
    );
  }
}

class _RecitationCard extends StatelessWidget {
  final Recitation recitation;

  const _RecitationCard({required this.recitation});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text(recitation.nameKey),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              recitation.arabic,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 22, height: 1.9),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.text('guide.transliteration')}: '
              '${recitation.transliteration}',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.text('guide.meaning')}: '
              '${l10n.text(recitation.meaningKey)}',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text(recitation.sourceKey),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
