import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import 'quran_meta.dart';
import 'quran_text.dart';
import 'surah_names.dart';

/// Hangi dilde hangi meal gösterilir (dosya kimliği).
///
/// Yalnızca telifi açık mealler buradadır. Türkçe: Elmalılı Hamdi Yazır'ın
/// 1935 ASLI (kamu malı). Tanzil'in `tr.yazir` dosyası sonradan
/// sadeleştirilmiş, ayrıca telifli bir baskıdır ve kullanılmaz; aslı
/// `tool/convert_elmalili_orijinal.py` ile girer. Arapça okuyana meal
/// gösterilmez.
const quranTranslations = {'en': 'en.pickthall', 'tr': 'tr.elmalili'};

final _jointRange = RegExp(r'^\((\d+)-(\d+)\)');

/// Meal bu âyeti bir önceki âyetle birlikte mi veriyor?
///
/// Elmalılı bazı âyet çiftlerini tek cümleyle çevirmiştir; metin
/// "(168-169) …" diye başlar ve iki âyette de aynıdır. İkincisinde aynı
/// cümleyi yinelemek yerine bunun söylenmesi için.
bool translatedWithPrevious(QuranText translation, int surah, int ayah) {
  if (ayah < 2) return false;
  final text = translation.ayah(surah, ayah);
  final range = _jointRange.firstMatch(text);
  return range != null &&
      int.parse(range.group(1)!) < ayah &&
      ayah <= int.parse(range.group(2)!) &&
      translation.ayah(surah, ayah - 1) == text;
}

String translationAsset(String id) => 'assets/quran/$id.txt.gz';

/// Metin, üst veri ve mealler bir arada.
class QuranBook {
  final QuranText text;
  final QuranMeta meta;

  /// Dil kodu → meal.
  final Map<String, QuranText> translations;

  QuranBook({
    required this.text,
    required this.meta,
    this.translations = const {},
  }) {
    for (final surah in meta.surahs) {
      if (text.ayahsIn(surah.number) != surah.ayahCount) {
        throw FormatException('${surah.number}. sûre metinle tutmuyor');
      }
    }
  }

  /// Sıkıştırılmış dosyalardan kurar: `load(asset)` dosyanın baytlarını
  /// verir (uygulamada rootBundle, testte diskteki dosya).
  static Future<QuranBook> load(
    Future<Uint8List> Function(String asset) load, {
    Future<QuranText> Function(Uint8List bytes)? decode,
  }) async {
    final open = decode ?? (bytes) async => QuranText.decode(bytes);
    final translations = <String, QuranText>{};
    for (final MapEntry(key: language, value: id)
        in quranTranslations.entries) {
      translations[language] = await open(await load(translationAsset(id)));
    }
    return QuranBook(
      text: await open(await load(QuranText.asset)),
      meta: QuranMeta.parse(
        utf8.decode(gzip.decode(await load(QuranMeta.asset))),
      ),
      translations: translations,
    );
  }

  QuranText? translationFor(String languageCode) => translations[languageCode];

  /// Sûrenin kullanıcının dilindeki adı.
  String surahName(int number, String languageCode) => switch (languageCode) {
    'tr' => turkishSurahNames[number - 1],
    'ar' => meta.surah(number).arabicName,
    _ => meta.surah(number).transliteration,
  };
}

/// Kitap ilk gerektiğinde bir kez yüklenir; büyük metinler arka planda
/// açılır ki ekran takılmasın.
final quranBookProvider = FutureProvider<QuranBook>(
  (ref) => QuranBook.load(
    (asset) async => (await rootBundle.load(asset)).buffer.asUint8List(),
    decode: (bytes) => compute(QuranText.decode, bytes),
  ),
);

const _lastPageKey = 'dini.quran.lastPage';

/// En son okunan Mushaf sayfası (1-604); hiç okunmadıysa null.
class LastReadPage extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final saved = int.tryParse(
      await ref.read(localStorageProvider).read(_lastPageKey) ?? '',
    );
    return saved != null && saved >= 1 && saved <= QuranMeta.pageCount
        ? saved
        : null;
  }

  Future<void> save(int page) async {
    state = AsyncData(page);
    await ref.read(localStorageProvider).write(_lastPageKey, '$page');
  }
}

final lastReadPageProvider = AsyncNotifierProvider<LastReadPage, int?>(
  LastReadPage.new,
);
