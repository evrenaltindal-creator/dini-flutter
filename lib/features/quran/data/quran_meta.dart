/// Tanzil'in Kuran üst verisi (`quran-data.xml`, CC BY): sûre adları,
/// cüzler, hizb çeyrekleri ve Medine Mushaf'ının 604 sayfasının hangi
/// âyetle başladığı.
///
/// Dosya `tool/import_quran.py` ile olduğu gibi girer. Burada yalnızca
/// okunur; biçimi düz ve sabit olduğu için XML kitaplığı gerekmez.
class QuranMeta {
  static const asset = 'assets/quran/quran-data.xml.gz';
  static const pageCount = 604;
  static const juzCount = 30;

  final List<SurahInfo> surahs;

  /// Her sayfanın, cüzün ve hizb çeyreğinin ilk âyetinin genel sırası
  /// (0 = Fâtiha 1, 6235 = Nâs 6).
  final List<int> pageStarts, juzStarts, quarterStarts;

  QuranMeta._({
    required this.surahs,
    required this.pageStarts,
    required this.juzStarts,
    required this.quarterStarts,
  });

  factory QuranMeta.parse(String xml) {
    final surahs = [
      for (final a in _elements(xml, 'sura'))
        SurahInfo(
          number: int.parse(a['index']!),
          ayahCount: int.parse(a['ayas']!),
          start: int.parse(a['start']!),
          arabicName: a['name']!,
          transliteration: a['tname']!,
          englishMeaning: a['ename']!,
          medinan: a['type'] == 'Medinan',
        ),
    ];
    if (surahs.length != 114) {
      throw FormatException('Üst veride ${surahs.length} sûre var');
    }
    List<int> starts(String tag, int expected) {
      final list = [
        for (final a in _elements(xml, tag))
          surahs[int.parse(a['sura']!) - 1].start + int.parse(a['aya']!) - 1,
      ];
      if (list.length != expected || list.first != 0) {
        throw FormatException('Üst veride $tag sayısı ${list.length}');
      }
      for (var i = 1; i < list.length; i++) {
        if (list[i] <= list[i - 1]) {
          throw FormatException('Üst veride $tag sırası bozuk: ${i + 1}');
        }
      }
      return list;
    }

    return QuranMeta._(
      surahs: surahs,
      pageStarts: starts('page', pageCount),
      juzStarts: starts('juz', juzCount),
      quarterStarts: starts('quarter', 240),
    );
  }

  static final _element = RegExp(r'<(\w+)\s([^>]*)/>');
  static final _attribute = RegExp(r'(\w+)="([^"]*)"');

  static Iterable<Map<String, String>> _elements(String xml, String tag) =>
      _element
          .allMatches(xml)
          .where((m) => m.group(1) == tag)
          .map(
            (m) => {
              for (final a in _attribute.allMatches(m.group(2)!))
                a.group(1)!: a.group(2)!,
            },
          );

  late final List<int> _surahStarts = [for (final s in surahs) s.start];

  SurahInfo surah(int number) => surahs[number - 1];

  /// Genel sıradaki âyetin sûresi ve numarası.
  AyahRef ayahAt(int index) {
    final surah = surahs[_floor(_surahStarts, index)];
    return AyahRef(surah.number, index - surah.start + 1);
  }

  int indexOf(AyahRef ref) => surah(ref.surah).start + ref.ayah - 1;

  /// Âyetin bulunduğu sayfa (1-604).
  int pageOf(AyahRef ref) => _floor(pageStarts, indexOf(ref)) + 1;

  /// Sayfanın cüzü (1-30). Dört cüz sayfanın ortasında başlar (4., 7.,
  /// 11. ve 26.); basılı Mushaf'taki gibi o sayfa yeni cüzle anılır, bu
  /// yüzden sayfanın SON âyetine bakılır.
  int juzOfPage(int page) {
    final last = (page < pageCount ? pageStarts[page] : 6236) - 1;
    return _floor(juzStarts, last) + 1;
  }

  int firstPageOfSurah(int surah) => pageOf(AyahRef(surah, 1));

  int firstPageOfJuz(int juz) => pageOf(ayahAt(juzStarts[juz - 1]));

  /// Sayfadaki âyetler, sûrelere bölünmüş olarak.
  List<PageSegment> segmentsOf(int page) {
    final from = pageStarts[page - 1];
    final to = page < pageCount ? pageStarts[page] : 6236;
    final segments = <PageSegment>[];
    var index = from;
    while (index < to) {
      final first = ayahAt(index);
      final info = surah(first.surah);
      final last = (info.start + info.ayahCount).clamp(0, to) - 1;
      segments.add(
        PageSegment(
          surah: first.surah,
          firstAyah: first.ayah,
          lastAyah: last - info.start + 1,
        ),
      );
      index = last + 1;
    }
    return segments;
  }

  /// Bu âyetle bir hizb çeyreği başlıyor mu?
  bool startsQuarter(AyahRef ref) => _binarySearch(quarterStarts, indexOf(ref));

  /// Sıralı listede [value]'dan küçük ya da eşit son öğenin yeri.
  static int _floor(List<int> sorted, int value) {
    var low = 0, high = sorted.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (sorted[mid] <= value) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  static bool _binarySearch(List<int> sorted, int value) =>
      sorted[_floor(sorted, value)] == value;
}

class SurahInfo {
  final int number, ayahCount;

  /// İlk âyetin genel sırası.
  final int start;
  final String arabicName, transliteration, englishMeaning;
  final bool medinan;

  const SurahInfo({
    required this.number,
    required this.ayahCount,
    required this.start,
    required this.arabicName,
    required this.transliteration,
    required this.englishMeaning,
    required this.medinan,
  });
}

class AyahRef {
  final int surah, ayah;
  const AyahRef(this.surah, this.ayah);

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => '$surah:$ayah';
}

/// Bir sayfada tek sûreye düşen âyetler.
class PageSegment {
  final int surah, firstAyah, lastAyah;
  const PageSegment({
    required this.surah,
    required this.firstAyah,
    required this.lastAyah,
  });

  bool get startsSurah => firstAyah == 1;
}
