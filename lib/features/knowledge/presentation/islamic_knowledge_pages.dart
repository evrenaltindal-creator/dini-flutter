import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/readable_width.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/islamic_knowledge.dart';

class IslamicKnowledgeView extends StatelessWidget {
  const IslamicKnowledgeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        18,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_library_outlined, size: 32),
                const SizedBox(height: 12),
                Text(
                  l10n.text('knowledge.title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.text('knowledge.intro'),
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
        ...islamicKnowledgeSections.map(
          (section) => _SectionCard(section: section),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0),
          child: Text(
            l10n.text('knowledge.disclaimer'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: BackdropPalette.mutedText, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class KnowledgeCategoryPage extends StatelessWidget {
  final KnowledgeSection section;

  const KnowledgeCategoryPage({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: BackdropPalette.text,
        title: Text(l10n.text(section.titleKey)),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            8,
            16,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  l10n.text(section.introKey),
                  style: const TextStyle(height: 1.55),
                ),
              ),
            ),
            ...section.articles.map(
              (article) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    18,
                    8,
                    12,
                    8,
                  ),
                  title: Text(l10n.text(article.titleKey)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l10n.text(article.summaryKey)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/knowledge/${section.id}/${article.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KnowledgeArticlePage extends StatelessWidget {
  final KnowledgeSection section;
  final KnowledgeArticle article;

  const KnowledgeArticlePage({
    super.key,
    required this.section,
    required this.article,
  });

  Future<void> _openSource(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(article.sourceUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('knowledge.sourceError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paragraphs = l10n.text(article.bodyKey).split('\n\n');
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: BackdropPalette.text,
        title: Text(l10n.text(article.titleKey)),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            8,
            16,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text(article.titleKey),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    for (final paragraph in paragraphs) ...[
                      Text(paragraph, style: const TextStyle(height: 1.65)),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text('knowledge.source'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(article.sourceName),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _openSource(context),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.text('knowledge.openSource')),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0),
              child: Text(
                l10n.text('knowledge.disclaimer'),
                style: const TextStyle(
                  color: BackdropPalette.mutedText,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final KnowledgeSection section;

  const _SectionCard({required this.section});

  IconData get icon => switch (section.id) {
    'prophets' => Icons.history_edu_outlined,
    'religions' => Icons.public_outlined,
    _ => Icons.balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/knowledge/${section.id}'),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 12, 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text(section.titleKey),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(l10n.text(section.introKey), maxLines: 2),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
