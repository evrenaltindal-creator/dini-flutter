import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/book_text_reader.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/prayer_flow.dart';
import '../domain/worship_guide.dart';
import 'guided_prayer_page.dart';

/// The book uses the existing sourced prayer/recitation library. No new
/// religious text or translation is introduced by the layout change.
class WorshipBookReader extends StatefulWidget {
  final bool wuduOnly;
  const WorshipBookReader({super.key, this.wuduOnly = false});
  @override
  State<WorshipBookReader> createState() => _WorshipBookReaderState();
}

class _WorshipBookReaderState extends State<WorshipBookReader>
    with AutomaticKeepAliveClientMixin {
  bool duas = false;
  RecitationId selected = guideRecitationIds.first;
  int prayerIndex = 0;
  bool restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!restored) {
      final saved = PageStorage.maybeOf(context)
          ?.readState(context, identifier: 'worship-book-choice');
      if (saved is (bool, RecitationId, int)) {
        duas = saved.$1;
        selected = saved.$2;
        prayerIndex = saved.$3;
      }
      restored = true;
    }
  }

  void _change(VoidCallback change) {
    setState(change);
    PageStorage.maybeOf(context)?.writeState(context, (
      duas,
      selected,
      prayerIndex,
    ), identifier: 'worship-book-choice');
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final recitation = recitationLibrary[selected]!;
    final wudu = [
      l10n.text('worship.wudu'),
      l10n.text('guide.wuduIntro'),
      for (var i = 1; i <= 8; i++) '$i. ${l10n.text('guide.wuduStep$i')}',
      l10n.text('guide.source'),
    ].join('\n\n');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 6),
      child: Column(
        children: [
          if (!widget.wuduOnly)
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _change(() => duas = false),
                  child: Text(l10n.text('worship.tabPrayer')),
                ),
                TextButton(
                  onPressed: () => _change(() => duas = true),
                  child: Text(l10n.text('book.duas')),
                ),
                if (duas)
                  DropdownButton<RecitationId>(
                    value: selected,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final id in guideRecitationIds)
                        if (recitationLibrary[id]!.isComplete)
                          DropdownMenuItem(
                            value: id,
                            child: Text(
                              l10n.text(recitationLibrary[id]!.nameKey),
                            ),
                          ),
                    ],
                    onChanged: (value) => _change(() => selected = value!),
                  ),
                if (!duas) ...[
                  DropdownButton<int>(
                    value: prayerIndex,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var i = 0; i < dailyPrayerGuides.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            l10n.prayer(dailyPrayerGuides[i].prayer.name),
                          ),
                        ),
                    ],
                    onChanged: (value) => _change(() => prayerIndex = value!),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(
                      GuidedPrayerPage.routeFor(
                        dailyPrayerGuides[prayerIndex].prayer,
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(l10n.text('hoca.start')),
                  ),
                ],
              ],
            ),
          Expanded(
            child: BookTextReader(
              key: ValueKey(
                widget.wuduOnly
                    ? 'wudu'
                    : duas
                    ? selected
                    : 'prayer-$prayerIndex',
              ),
              storageId: widget.wuduOnly
                  ? 'wudu-book'
                  : duas
                  ? 'dua-${selected.name}'
                  : 'prayer-book-$prayerIndex',
              readingDirection: duas && !widget.wuduOnly
                  ? TextDirection.rtl
                  : null,
              arabic: duas && !widget.wuduOnly,
              text: widget.wuduOnly
                  ? wudu
                  : duas
                  ? '${l10n.text(recitation.nameKey)}\n\n${recitation.arabic}\n\n${l10n.text(recitation.sourceKey)}'
                  : prayerBookText(
                      context,
                      only: dailyPrayerGuides[prayerIndex],
                    ),
            ),
          ),
          if (duas && !widget.wuduOnly)
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '${recitation.transliteration}\n\n${l10n.text(recitation.meaningKey)}\n\n${l10n.text(recitation.sourceKey)}',
                      style: const TextStyle(fontSize: 17, height: 1.65),
                    ),
                  ),
                ),
              ),
              child: Text(l10n.text('guide.meaning')),
            ),
        ],
      ),
    );
  }
}

String prayerBookText(BuildContext context, {DailyPrayerGuide? only}) {
  final l10n = context.l10n;
  String label(PrayerPartKind kind) => l10n.text(switch (kind) {
    PrayerPartKind.firstSunnah => 'guide.firstSunnah',
    PrayerPartKind.fard => 'guide.fard',
    PrayerPartKind.finalSunnah => 'guide.finalSunnah',
    PrayerPartKind.witr => 'guide.witr',
  });
  return [
    l10n.text('guide.prayerTitle'),
    l10n.text('guide.prayerIntro'),
    for (final guide in only == null ? dailyPrayerGuides : [only]) ...[
      l10n.prayer(guide.prayer.name),
      for (final part in prayerFlow(guide)) ...[
        label(part.kind),
        for (final rakat in part.rakats) ...[
          l10n.text('guide.rakatLabel', {'index': rakat.index}),
          for (final key in rakat.movementKeys) l10n.text(key),
        ],
        l10n.text('guide.finalSitting'),
        l10n.text(finalSittingKey),
      ],
    ],
    l10n.text('guide.schoolNotice'),
    l10n.text('guide.source'),
  ].join('\n\n');
}
