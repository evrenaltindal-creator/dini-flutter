import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/layout/book_layout.dart';
import '../data/quran_book.dart';
import '../data/quran_meta.dart';
import 'mushaf_page.dart';
import 'page_turner.dart';
import 'quran_book_loader.dart';
import '../../home/presentation/mosque_backdrop.dart';
import 'quran_meal_page.dart';

/// Open the saved page directly, waiting for storage before choosing a page.
/// Saving page 1 while the asynchronous bookmark is loading would erase it.
class QuranStartPage extends ConsumerStatefulWidget {
  const QuranStartPage({super.key});
  @override
  ConsumerState<QuranStartPage> createState() => _QuranStartPageState();
}

class _QuranStartPageState extends ConsumerState<QuranStartPage> {
  int? initialPage;
  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(lastReadPageProvider);
    if (saved.isLoading && initialPage == null) {
      return const Center(child: Icon(Icons.menu_book_outlined));
    }
    initialPage ??= saved.valueOrNull ?? 1;
    return QuranReaderPage(initialPage: initialPage!);
  }
}

/// Mushaf kipi: 604 sayfa, parmakla kitap gibi çevrilir.
///
/// Açılan her sayfa "kaldığın yer" olarak saklanır. Kullanıcının dilinde
/// meal varsa üstteki düğme aynı sûreyi meal ile açar.
class QuranReaderPage extends ConsumerStatefulWidget {
  final int initialPage;

  const QuranReaderPage({super.key, required this.initialPage});

  static String routeFor(int page) => '/quran/page/$page';

  @override
  ConsumerState<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends ConsumerState<QuranReaderPage> {
  late int page = widget.initialPage.clamp(1, QuranMeta.pageCount);
  late final PageController spreads = PageController(
    initialPage: (page - 1) ~/ 2,
  );
  bool? wasExpanded;

  @override
  void dispose() {
    spreads.dispose();
    super.dispose();
  }

  void _goTo(int target) {
    setState(() => page = target.clamp(1, QuranMeta.pageCount));
    if (spreads.hasClients) spreads.jumpToPage((page - 1) ~/ 2);
    // A new single-page controller is keyed to the selected page below.
    _remember();
  }

  Future<void> _choose(QuranBook book, {required bool juz}) async {
    var surah = book.meta.segmentsOf(page).first.surah;
    var ayah = 1;
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, update) => Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: juz
                ? SizedBox(
                    height: MediaQuery.sizeOf(context).height * .55,
                    child: ListView.builder(
                      itemCount: 30,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(
                          context.l10n.text('quran.juzLabel', {
                            'juz': index + 1,
                          }),
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          book.meta.firstPageOfJuz(index + 1),
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: surah,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.text('quran.surahs'),
                        ),
                        items: [
                          for (var i = 1; i <= 114; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                book.surahName(
                                  i,
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) => update(() {
                          surah = value!;
                          ayah = 1;
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey(surah),
                        initialValue: ayah,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.text('quran.verses'),
                        ),
                        items: [
                          for (
                            var i = 1;
                            i <= book.meta.surah(surah).ayahCount;
                            i++
                          )
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (value) => update(() => ayah = value!),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          book.meta.pageOf(AyahRef(surah, ayah)),
                        ),
                        child: Text(context.l10n.text('quran.openVerse')),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (target != null && mounted) _goTo(target);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_remember);
  }

  void _remember() {
    if (mounted) ref.read(lastReadPageProvider.notifier).save(page);
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return QuranBookLoader(
      builder: (context, book) {
        final surah = book.meta.segmentsOf(page).first.surah;
        final expanded = bookDisplayOf(context);
        if (expanded && wasExpanded != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && spreads.hasClients) {
              spreads.jumpToPage((page - 1) ~/ 2);
            }
          });
        }
        wasExpanded = expanded;
        return BackdropScaffold(
          readable: !expanded,
          title:
              '${book.surahName(surah, language)} · '
              '${context.l10n.text('quran.pageLabel', {'page': page})}',
          actions: [
            if (book.translationFor(language) != null)
              IconButton(
                tooltip: context.l10n.text('quran.mealView'),
                icon: const Icon(Icons.translate),
                onPressed: () => context.push(QuranMealPage.routeFor(surah)),
              ),
          ],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 10),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _choose(book, juz: false),
                        child: Text(context.l10n.text('quran.verses')),
                      ),
                      TextButton(
                        onPressed: () => _choose(book, juz: true),
                        child: Text(context.l10n.text('quran.juzs')),
                      ),
                      if (expanded) ...[
                        IconButton(
                          tooltip: context.l10n.text('book.previous'),
                          onPressed: page > 2
                              ? () => _goTo((((page - 1) ~/ 2) - 1) * 2 + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          tooltip: context.l10n.text('book.next'),
                          onPressed: page < 603
                              ? () => _goTo((((page - 1) ~/ 2) + 1) * 2 + 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: expanded
                        ? PageView.builder(
                            controller: spreads,
                            reverse: true,
                            itemCount: QuranMeta.pageCount ~/ 2,
                            onPageChanged: (index) {
                              if ((page - 1) ~/ 2 != index) {
                                setState(() => page = index * 2 + 1);
                                _remember();
                              }
                            },
                            itemBuilder: (context, index) => BookSpread(
                              readingDirection: TextDirection.rtl,
                              first: MushafPage(
                                book: book,
                                page: index * 2 + 1,
                              ),
                              second: MushafPage(
                                book: book,
                                page: index * 2 + 2,
                              ),
                            ),
                          )
                        : PageTurner(
                            key: ValueKey('reader-$page'),
                            itemCount: QuranMeta.pageCount,
                            initialPage: page - 1,
                            onPageChanged: (index) {
                              setState(() => page = index + 1);
                              _remember();
                            },
                            itemBuilder: (context, index) =>
                                MushafPage(book: book, page: index + 1),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
