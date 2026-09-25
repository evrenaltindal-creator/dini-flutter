import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class WuduGuideView extends StatelessWidget {
  const WuduGuideView({super.key});

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
        Text(
          l10n.text('worship.wudu'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.text('guide.wuduIntro'), style: const TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/guides/wudu_steps.png',
            fit: BoxFit.fitWidth,
            semanticLabel: l10n.text('guide.wuduImageLabel'),
          ),
        ),
        const SizedBox(height: 18),
        for (var index = 1; index <= 8; index++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('$index')),
              title: Text(l10n.text('guide.wuduStep$index')),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n.text('guide.source'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
