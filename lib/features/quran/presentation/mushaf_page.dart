import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/quran_book.dart';
import '../data/quran_meta.dart';
import 'quran_style.dart';

/// Medine Mushaf'ının bir sayfası: tezhipli çerçeve, üstte cüz ve sûre,
/// sayfaya düşen âyetler, altta sayfa numarası.
///
/// Sayfanın âyetleri basılı Mushaf'la aynıdır (Tanzil sayfa verisi). Yazı
/// boyutu, sayfanın âyetleri çerçeveye sığacak en büyük boydur: basılı
/// sayfa 15 satırdır, telefonda bu boy ekrana göre seçilir. En küçük boyda
/// bile sığmazsa (çok dar ekran) sayfa kendi içinde kayar.
class MushafPage extends StatelessWidget {
  final QuranBook book;
  final int page;

  const MushafPage({super.key, required this.book, required this.page});

  static const maxFontSize = 30.0;
  static const minFontSize = 16.0;

  /// Sığdırma ölçümü pahalıdır ve sayfa çevrilirken her karede yeniden
  /// kurulur; aynı sayfa ve alan için sonuç saklanır.
  static final _fitCache = <(int, double, double, String), double>{};

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final meta = book.meta;
    final segments = meta.segmentsOf(page);
    final first = meta.surah(segments.first.surah);
    // Mushaf metni yazı boyutunu sayfaya göre kendisi seçer; telefonun yazı
    // büyütmesi ölçümü bozardı. Meal kipi büyütmeye uyar.
    return MediaQuery.withNoTextScaling(
      // Temanın yazı biçimi (harf aralığı, satır yüksekliği) burada
      // SIFIRLANIR: sığdırma ölçümü yalnızca verilen biçimleri görür; ekrana
      // çizilen metin temadan fazladan bir şey alırsa ölçüm tutmaz ve sayfa
      // taşar.
      child: DefaultTextStyle(
        style: const TextStyle(color: QuranPalette.ink),
        child: MushafFrame(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 14),
          // Mushaf sayfası Arapçadır ve her dilde sağdan sola dizilir; bu,
          // arayüzün yönü değil metnin kendi yönüdür.
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                _PageBar(
                  start: 'الجزء ${arabicDigits(meta.juzOfPage(page))}',
                  end: first.arabicName,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final fontSize = _fitCache.putIfAbsent((
                        page,
                        constraints.maxWidth,
                        constraints.maxHeight,
                        language,
                      ), () => _fit(context, segments, constraints, language));
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: [
                            for (final segment in segments)
                              ..._segment(context, segment, fontSize, language),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                StarMedallion(
                  label: arabicDigits(page),
                  size: 34,
                  fontFamily: quranTitleFamily,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<(int, String)> _ayahs(PageSegment segment) => [
    for (var a = segment.firstAyah; a <= segment.lastAyah; a++)
      (a, book.text.ayahBody(segment.surah, a)),
  ];

  List<Widget> _segment(
    BuildContext context,
    PageSegment segment,
    double fontSize,
    String language,
  ) {
    final info = book.meta.surah(segment.surah);
    final basmala = book.text.basmalaOf(segment.surah);
    return [
      if (segment.startsSurah) ...[
        const SizedBox(height: _headerGap),
        SurahHeader(
          arabicName: 'سورة ${info.arabicName}',
          height: headerHeightFor(fontSize),
        ),
        if (basmala != null)
          BasmalaLine(text: basmala, fontSize: fontSize)
        else
          const SizedBox(height: _headerGap),
      ],
      MushafText(ayahs: _ayahs(segment), fontSize: fontSize),
    ];
  }

  static const _headerGap = 8.0;

  /// Sayfadaki sûre başlığının yüksekliği: basılı Mushaf'ta başlık bir
  /// satır kadardır; burada yazıyla birlikte büyür, 64'ü geçmez.
  static double headerHeightFor(double fontSize) =>
      (fontSize * 2.1).clamp(36.0, SurahHeader.cartoucheHeight);

  /// Sayfanın sığdığı en büyük yazı boyu (ikili arama).
  double _fit(
    BuildContext context,
    List<PageSegment> segments,
    BoxConstraints constraints,
    String language,
  ) {
    final width = constraints.maxWidth;
    double measure(InlineSpan span, TextAlign align) {
      final painter = TextPainter(
        text: span,
        textAlign: align,
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: width);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    double heightAt(double fontSize) {
      var total = 0.0;
      for (final segment in segments) {
        if (segment.startsSurah) {
          total += _headerGap + headerHeightFor(fontSize);
          final basmala = book.text.basmalaOf(segment.surah);
          total += basmala == null
              ? _headerGap
              : 2 * BasmalaLine.verticalPadding +
                    measure(
                      TextSpan(
                        text: basmala,
                        style: BasmalaLine.styleFor(fontSize),
                      ),
                      TextAlign.center,
                    );
        }
        total += measure(
          MushafText.spanFor(_ayahs(segment), fontSize),
          TextAlign.justify,
        );
      }
      return total;
    }

    var low = minFontSize, high = maxFontSize;
    if (heightAt(high) <= constraints.maxHeight) return high;
    if (heightAt(low) > constraints.maxHeight) return low;
    while (high - low > .25) {
      final mid = (low + high) / 2;
      if (heightAt(mid) <= constraints.maxHeight) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

/// "Bakara · Medenî · 286 âyet": sûre başlığının altındaki satır ve sûre
/// listesindeki açıklama.
String surahCaption(
  BuildContext context,
  QuranBook book,
  int surah, {
  bool withName = true,
}) {
  final l10n = context.l10n;
  final language = Localizations.localeOf(context).languageCode;
  final info = book.meta.surah(surah);
  return [
    if (withName && language != 'ar') book.surahName(surah, language),
    if (language == 'en') info.englishMeaning,
    l10n.text(info.medinan ? 'quran.medinan' : 'quran.meccan'),
    l10n.text('quran.ayahCount', {'count': info.ayahCount}),
  ].join(' · ');
}

/// Sayfanın üstündeki ince satır: bir yanda cüz, öbür yanda sûre.
class _PageBar extends StatelessWidget {
  final String start, end;

  const _PageBar({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: quranTitleFamily,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: QuranPalette.gold,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(start, style: style),
          Text(end, style: style),
        ],
      ),
    );
  }
}
