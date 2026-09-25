import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/quran_book.dart';

/// Kitap yüklenene kadar sakin bir yer tutucu, yüklenince [builder].
///
/// Yer tutucu bilerek dönen bir gösterge DEĞİLDİR: metin bir kez açılır,
/// kısa sürer; sürekli dönen bir çark testlerin "ekran durdu" beklemesini de
/// sonsuza kadar bekletirdi.
class QuranBookLoader extends ConsumerWidget {
  final Widget Function(BuildContext context, QuranBook book) builder;

  const QuranBookLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(quranBookProvider)) {
        AsyncData(:final value) => builder(context, value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.text('quran.loadError'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BackdropPalette.text),
            ),
          ),
        ),
        _ => const Center(
          child: Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: BackdropPalette.mutedText,
          ),
        ),
      };
}
