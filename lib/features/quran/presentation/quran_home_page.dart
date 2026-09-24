import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/quran_book.dart';
import 'mushaf_page.dart';
import 'quran_book_loader.dart';
import 'quran_reader_page.dart';
import '../../home/presentation/mosque_backdrop.dart';
import 'quran_style.dart';

/// Kuran sekmesi: kaldığın yer, sûreler ve cüzler.
///
/// Sûreye ya da cüze dokununca Mushaf o sayfadan açılır.
class QuranHomePage extends ConsumerStatefulWidget {
  const QuranHomePage({super.key});

  @override
  ConsumerState<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends ConsumerState<QuranHomePage> {
  bool showJuz = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BackdropScaffold(
      title: l10n.text('nav.quran'),
      body: QuranBookLoader(
        builder: (context, book) {
          final lastPage = ref.watch(lastReadPageProvider).valueOrNull;
          final count = showJuz ? 30 : 114;
          return ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
            itemCount: count + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lastPage != null) ...[
                      _ContinueCard(book: book, page: lastPage),
                      const SizedBox(height: 14),
                    ],
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.text('quran.surahs')),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.text('quran.juzs')),
                        ),
                      ],
                      selected: {showJuz},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => showJuz = value.single),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }
              return showJuz
                  ? _JuzTile(book: book, juz: index)
                  : _SurahTile(book: book, surah: index);
            },
          );
        },
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final QuranBook book;
  final int page;

  const _ContinueCard({required this.book, required this.page});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final surah = book.meta.segmentsOf(page).first.surah;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(QuranReaderPage.routeFor(page)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [QuranPalette.green, QuranPalette.greenDeep],
            ),
            border: Border.all(color: QuranPalette.gold, width: 1.2),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark,
                color: QuranPalette.goldLight,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text('quran.continue'),
                      style: const TextStyle(
                        color: QuranPalette.cream,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        book.surahName(surah, language),
                        l10n.text('quran.pageLabel', {'page': page}),
                        l10n.text('quran.juzLabel', {
                          'juz': book.meta.juzOfPage(page),
                        }),
                      ].join(' · '),
                      style: const TextStyle(
                        color: QuranPalette.goldLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: QuranPalette.goldLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste satırı: yıldız madalyonda numara, adı ve açıklaması, sonda
/// Arapça adı altın harflerle.
class _Row extends StatelessWidget {
  final String number, title, caption;

  /// Arapça ad; arayüz zaten Arapçaysa başlıkla aynı olacağı için yok.
  final String? arabic;
  final VoidCallback onTap;

  const _Row({
    required this.number,
    required this.title,
    required this.caption,
    required this.arabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
        child: Row(
          children: [
            StarMedallion(label: number, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (arabic case final arabic?) ...[
              const SizedBox(width: 8),
              Text(
                arabic,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: quranTitleFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: QuranPalette.goldLight,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SurahTile extends StatelessWidget {
  final QuranBook book;
  final int surah;

  const _SurahTile({required this.book, required this.surah});

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final info = book.meta.surah(surah);
    return _Row(
      number: '$surah',
      title: book.surahName(surah, language),
      caption: surahCaption(context, book, surah, withName: false),
      arabic: language == 'ar' ? null : info.arabicName,
      onTap: () => context.push(
        QuranReaderPage.routeFor(book.meta.firstPageOfSurah(surah)),
      ),
    );
  }
}

class _JuzTile extends StatelessWidget {
  final QuranBook book;
  final int juz;

  const _JuzTile({required this.book, required this.juz});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final meta = book.meta;
    final start = meta.ayahAt(meta.juzStarts[juz - 1]);
    final page = meta.firstPageOfJuz(juz);
    return _Row(
      number: '$juz',
      title: l10n.text('quran.juzLabel', {'juz': juz}),
      caption: [
        '${book.surahName(start.surah, language)} ${start.ayah}',
        l10n.text('quran.pageLabel', {'page': page}),
      ].join(' · '),
      arabic: language == 'ar' ? null : 'الجزء ${arabicDigits(juz)}',
      onTap: () => context.push(QuranReaderPage.routeFor(page)),
    );
  }
}
