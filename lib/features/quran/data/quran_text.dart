import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tanzil'in Uthmani Kuran metni (sürüm 1.1, CC BY 3.0).
///
/// Metin `tool/import_quran.py` ile uygulamaya girer ve dosyada TEK HARFİ
/// bile değiştirilmez (Tanzil'in kullanım şartı). Burada yalnızca okunur:
/// sûre ve âyet numarasına göre bölünür, telif bloğu atlanır.
class QuranText {
  static const asset = 'assets/quran/quran-uthmani.txt.gz';
  static const surahCount = 114;
  static const ayahCount = 6236;

  /// `surahs[s - 1][a - 1]`, s. sûrenin a. âyeti.
  final List<List<String>> surahs;

  const QuranText._(this.surahs);

  /// "sûre|âyet|metin" satırlarını okur. Sıra bozuksa ya da sayı
  /// tutmuyorsa hata verir: eksik bir Kuran sessizce gösterilmez.
  factory QuranText.parse(String raw) {
    final surahs = <List<String>>[];
    for (final line in raw.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final first = line.indexOf('|');
      final second = line.indexOf('|', first + 1);
      if (first < 1 || second < 0) {
        throw FormatException('Kuran satırı okunamadı', line);
      }
      final surah = int.parse(line.substring(0, first));
      final ayah = int.parse(line.substring(first + 1, second));
      if (ayah == 1 && surah == surahs.length + 1) {
        surahs.add([]);
      } else if (surahs.isEmpty ||
          surah != surahs.length ||
          ayah != surahs.last.length + 1) {
        throw FormatException('Kuran metninde sıra bozuk: $surah:$ayah');
      }
      surahs.last.add(line.substring(second + 1));
    }
    final total = surahs.fold(0, (sum, surah) => sum + surah.length);
    if (surahs.length != surahCount || total != ayahCount) {
      throw FormatException(
        'Kuran metni eksik: ${surahs.length} sûre, $total âyet',
      );
    }
    return QuranText._(surahs);
  }

  /// Sıkıştırılmış dosyayı açar.
  static QuranText decode(Uint8List bytes) =>
      QuranText.parse(utf8.decode(gzip.decode(bytes)));

  int ayahsIn(int surah) => surahs[surah - 1].length;

  /// Tanzil'in yazdığı hâliyle âyet (sûre başındaki Besmele dahil).
  String ayah(int surah, int ayah) => surahs[surah - 1][ayah - 1];

  /// Sûrenin başındaki Besmele; yoksa null.
  ///
  /// Tanzil Besmele'yi Fâtiha ve Tevbe dışındaki sûrelerin 1. âyetinin
  /// başına yazar. Mushaf'ta Besmele âyetten ayrı, sûre başlığının altında
  /// durur; bu yüzden gösterirken ilk dört kelime ayrılır. Metin yine
  /// harfi harfine Tanzil'inkidir (Tîn ve Kadr'de "بِّسْمِ" şeddelidir).
  /// Fâtiha'da Besmele âyetin kendisidir, Tevbe'de Besmele yoktur.
  String? basmalaOf(int surah) {
    if (surah == 1 || surah == 9) return null;
    return _splitBasmala(ayah(surah, 1)).$1;
  }

  /// Âyetin gösterilecek metni: sûre başındaki Besmele ayrılmış olarak.
  String ayahBody(int surah, int ayah) {
    final text = this.ayah(surah, ayah);
    if (ayah != 1 || surah == 1 || surah == 9) return text;
    return _splitBasmala(text).$2;
  }

  static (String, String) _splitBasmala(String text) {
    var end = -1;
    for (var word = 0; word < 4; word++) {
      end = text.indexOf(' ', end + 1);
      if (end < 0) {
        throw FormatException('Sûre başında Besmele yok', text);
      }
    }
    return (text.substring(0, end), text.substring(end + 1));
  }
}

/// Metin ilk gerektiğinde bir kez açılır; açma işi arka planda yapılır ki
/// 1,4 MB'lık metin çözülürken ekran takılmasın.
final quranTextProvider = FutureProvider<QuranText>((ref) async {
  final data = await rootBundle.load(QuranText.asset);
  return compute(QuranText.decode, data.buffer.asUint8List());
});
