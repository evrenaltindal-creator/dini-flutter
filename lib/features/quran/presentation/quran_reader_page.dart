import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/quran_book.dart';
import '../data/quran_meta.dart';
import 'mushaf_page.dart';
import 'page_turner.dart';
import 'quran_book_loader.dart';
import '../../home/presentation/mosque_backdrop.dart';
import 'quran_meal_page.dart';

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
        return BackdropScaffold(
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
              child: PageTurner(
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
          ),
        );
      },
    );
  }
}
