import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

/// Kuran bölümü henüz hazır değil. Boş bir çatı göstermek yerine ne
/// beklendiğini ve neden beklendiğini açıkça anlatır; metin kaynağı ve
/// kullanım izni netleşmeden içerik eklenmeyecek.
class QuranComingSoonPage extends StatelessWidget {
  const QuranComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.text('nav.quran')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 32),
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: scheme.primary,
              semanticLabel: l10n.text('nav.quran'),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.text('quran.comingSoonTitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.text('quran.comingSoonBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.text('quran.comingSoonNote'),
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
