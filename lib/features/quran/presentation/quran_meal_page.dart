import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/quran_book.dart';
import 'mushaf_page.dart';
import 'quran_book_loader.dart';
import '../../home/presentation/mosque_backdrop.dart';
import 'quran_reader_page.dart';
import 'quran_style.dart';

/// Meal kipi: bir sûrenin âyetleri, her birinin altında kullanıcının
/// dilinde meali. Mealin uzunluğu âyetten âyete değiştiği için sayfalara
/// bölünmez, aşağı kayar; sonda önceki ve sonraki sûreye geçilir.
class QuranMealPage extends StatelessWidget {
  final int surah;

  const QuranMealPage({super.key, required this.surah});

  static String routeFor(int surah) => '/quran/surah/$surah';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    return QuranBookLoader(
      builder: (context, book) {
        final info = book.meta.surah(surah);
        final translation = book.translationFor(language);
        final basmala = book.text.basmalaOf(surah);
        return BackdropScaffold(
          title: book.surahName(surah, language),
          actions: [
            IconButton(
              tooltip: l10n.text('quran.mushafView'),
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: () => context.push(
                QuranReaderPage.routeFor(book.meta.firstPageOfSurah(surah)),
              ),
            ),
          ],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 10),
              child: MushafFrame(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 18),
                child: ListView.builder(
                  itemCount: info.ayahCount + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          SurahHeader(
                            arabicName: 'سورة ${info.arabicName}',
                            caption: surahCaption(context, book, surah),
                          ),
                          if (basmala != null) BasmalaLine(text: basmala),
                        ],
                      );
                    }
                    if (index == info.ayahCount + 1) {
                      return _Footer(
                        surah: surah,
                        source: translation == null
                            ? null
                            : l10n.text(
                                'quran.source.${quranTranslations[language]}',
                              ),
                      );
                    }
                    return AyahWithTranslation(
                      number: index,
                      numberLabel: '$index',
                      arabic: book.text.ayahBody(surah, index),
                      translation: translation == null
                          ? null
                          : translatedWithPrevious(translation, surah, index)
                          ? l10n.text('quran.jointTranslation')
                          : translation.ayah(surah, index),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Önceki ve sonraki sûre; mealin kaynağı.
class _Footer extends StatelessWidget {
  final int surah;
  final String? source;

  const _Footer({required this.surah, required this.source});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const style = TextStyle(color: QuranPalette.green);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              if (surah > 1)
                TextButton.icon(
                  onPressed: () => context.pushReplacement(
                    QuranMealPage.routeFor(surah - 1),
                  ),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: QuranPalette.green,
                  ),
                  label: Text(l10n.text('quran.previousSurah'), style: style),
                ),
              if (surah < 114)
                TextButton.icon(
                  onPressed: () => context.pushReplacement(
                    QuranMealPage.routeFor(surah + 1),
                  ),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: QuranPalette.green,
                  ),
                  label: Text(l10n.text('quran.nextSurah'), style: style),
                ),
            ],
          ),
          if (source != null) ...[
            const SizedBox(height: 8),
            Text(
              source!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QuranPalette.mutedInk,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
