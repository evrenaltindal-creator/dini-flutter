import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';
import 'package:dini_flutter/features/quran/data/quran_meta.dart';
import 'package:dini_flutter/features/quran/data/quran_text.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = File(QuranText.asset).readAsBytesSync();
  final raw = utf8.decode(gzip.decode(bytes));
  final quran = QuranText.decode(bytes);

  group('pakete giren Kuran metni', () {
    test('114 sûre, 6236 âyet; bilinen sûre uzunlukları tutar', () {
      expect(quran.surahs, hasLength(114));
      expect(quran.surahs.fold(0, (sum, s) => sum + s.length), 6236);
      expect(quran.ayahsIn(1), 7); // Fâtiha
      expect(quran.ayahsIn(2), 286); // Bakara
      expect(quran.ayahsIn(9), 129); // Tevbe
      expect(quran.ayahsIn(36), 83); // Yâsîn
      expect(quran.ayahsIn(112), 4); // İhlâs
      expect(quran.ayahsIn(114), 6); // Nâs
    });

    test('pakete giren her Kuran dosyası kaynak notundaki özetle aynı', () {
      // Metin, üst veri ve mealler: hiçbirine elle dokunulmaz.
      final note = File('assets/quran/SOURCE.txt').readAsStringSync();
      final entries = RegExp(
        r'Dosya: (\S+) \(gzip[^\n]*\nSHA-256 \(sıkıştırılmamış\): ([0-9a-f]{64})',
      ).allMatches(note).toList();
      final listed = {for (final e in entries) e.group(1)!};
      expect(listed, {
        QuranText.asset,
        QuranMeta.asset,
        for (final id in quranTranslations.values) translationAsset(id),
      });
      for (final entry in entries) {
        final data = gzip.decode(File(entry.group(1)!).readAsBytesSync());
        expect(
          sha256.convert(data).toString(),
          entry.group(2),
          reason: entry.group(1),
        );
      }
      // Pakette notta yazmayan dosya yok.
      final packaged = Directory('assets/quran')
          .listSync()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((path) => path.endsWith('.gz'))
          .toSet();
      expect(packaged, listed);
    });

    test('Tanzil dosyası harfi harfine: özet kaynak notuyla aynı', () {
      // Tanzil'in şartı metnin değiştirilmemesidir. Dosyaya elle dokunan
      // olursa özet tutmaz.
      final note = File('assets/quran/SOURCE.txt').readAsStringSync();
      final recorded = RegExp(r'SHA-256 \(sıkıştırılmamış\): ([0-9a-f]{64})')
          .firstMatch(note)
          ?.group(1);
      expect(recorded, isNotNull, reason: 'Kaynak notunda özet yok.');
      expect(sha256.convert(utf8.encode(raw)).toString(), recorded);
    });

    test('Tanzil telif bloğu dosyanın içinde duruyor', () {
      expect(raw, contains('Tanzil Quran Text (Uthmani, Version 1.1)'));
      expect(raw, contains('CHANGING IT IS NOT ALLOWED'));
      expect(raw, contains('Creative Commons Attribution 3.0'));
    });

    test('Hakkında sayfası kaynağı üç dilde yazar ve tanzil.net verir', () {
      for (final code in ['tr', 'en', 'ar']) {
        final credit = AppLocalizations(Locale(code)).text('about.quran');
        expect(credit, contains('tanzil.net'), reason: code);
        expect(credit, contains('CC BY 3.0'), reason: code);
        expect(credit, contains('1.1'), reason: code);
      }
    });
  });

  group('Besmele', () {
    // Tanzil'in harfleri ve hareke sırası; elle yazılan Arapçada hareke
    // sırası kolayca farklı çıkar, bu yüzden kod noktalarıyla.
    const basmala =
        '\u0628\u0650\u0633\u0652\u0645\u0650 '
        '\u0671\u0644\u0644\u0651\u064E\u0647\u0650 '
        '\u0671\u0644\u0631\u0651\u064E\u062D\u0652\u0645\u064E\u0640'
        '\u0670\u0646\u0650 '
        '\u0671\u0644\u0631\u0651\u064E\u062D\u0650\u064A\u0645\u0650';

    test("Fâtiha'da âyetin kendisi, Tevbe'de yok", () {
      expect(quran.ayah(1, 1), basmala);
      expect(quran.basmalaOf(1), isNull);
      expect(quran.ayahBody(1, 1), basmala);
      expect(quran.basmalaOf(9), isNull);
      expect(quran.ayahBody(9, 1), quran.ayah(9, 1));
    });

    test('diğer sûrelerde başlığın altına ayrılır, âyet numarasız kalır', () {
      expect(quran.basmalaOf(2), basmala);
      expect(
        quran.ayahBody(2, 1),
        '\u0627\u0644\u0653\u0645\u0653' /* Elif Lâm Mîm */,
      );
      expect(quran.basmalaOf(112), basmala);
      expect(
        quran.ayahBody(112, 1),
        startsWith('\u0642\u064F\u0644\u0652 ') /* Kul */,
      );
    });

    test('ayırma kayıpsızdır: Besmele + âyet, Tanzil satırının aynısı', () {
      for (var surah = 1; surah <= 114; surah++) {
        final head = quran.basmalaOf(surah);
        final joined = head == null
            ? quran.ayahBody(surah, 1)
            : '$head ${quran.ayahBody(surah, 1)}';
        expect(joined, quran.ayah(surah, 1), reason: '$surah. sûre');
        // Ayrılan kısım gerçekten Besmele: harekeler farklı olabilir
        // (Tîn ve Kadr'de "بِّسْمِ" şeddelidir) ama harfler aynıdır.
        if (head != null) {
          expect(_letters(head), _letters(basmala), reason: '$surah. sûre');
        }
      }
    });

    test("Neml 30'daki Besmele âyetin içinde kalır", () {
      expect(quran.ayahBody(27, 30), quran.ayah(27, 30));
      expect(_letters(quran.ayah(27, 30)), contains(_letters(basmala)));
    });
  });

  group('okuma', () {
    String text(Map<int, int> counts, {Set<String> skip = const {}}) => [
      '# yorum',
      for (final MapEntry(key: surah, value: count) in counts.entries)
        for (var ayah = 1; ayah <= count; ayah++)
          if (!skip.contains('$surah:$ayah')) '$surah|$ayah|metin',
      '',
    ].join('\n');

    final full = {for (var s = 1; s <= 114; s++) s: quran.ayahsIn(s)};

    test('tam metin okunur, yorumlar atlanır', () {
      expect(QuranText.parse(text(full)).surahs, hasLength(114));
    });

    test('eksik âyet, bozuk sıra ya da eksik sûre kabul edilmez', () {
      expect(
        () => QuranText.parse(text(full, skip: {'2:255'})),
        throwsFormatException,
      );
      expect(
        () => QuranText.parse(text({...full}..remove(114))),
        throwsFormatException,
      );
      expect(
        () => QuranText.parse(text({2: 3, ...full})),
        throwsFormatException,
      );
    });
  });

  group('tool/import_quran.py', () {
    late Directory root;
    late File input, meta, translation;
    final rawMeta = utf8.decode(
      gzip.decode(File(QuranMeta.asset).readAsBytesSync()),
    );
    final rawEnglish = utf8.decode(
      gzip.decode(File(translationAsset('en.pickthall')).readAsBytesSync()),
    );
    final rawTurkish = utf8.decode(
      gzip.decode(File(translationAsset('tr.elmalili')).readAsBytesSync()),
    );

    setUp(() {
      root = Directory.systemTemp.createTempSync('quran');
      input = File('${root.path}/quran-uthmani.txt');
      meta = File('${root.path}/quran-data.xml')..writeAsStringSync(rawMeta);
      translation = File('${root.path}/en.pickthall.txt')
        ..writeAsStringSync(rawEnglish);
      File('${root.path}/tr.elmalili.txt').writeAsStringSync(rawTurkish);
    });
    tearDown(() => root.deleteSync(recursive: true));

    Future<ProcessResult> run() => Process.run('python3', [
      'tool/import_quran.py',
      input.path,
      meta.path,
      '--translation',
      translation.path,
      '--translation',
      '${root.path}/tr.elmalili.txt',
      '--root',
      root.path,
    ]);

    test('dosyayı değiştirmeden sıkıştırır ve özetini yazar', () async {
      input.writeAsStringSync(raw);
      final result = await run();
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final out = File('${root.path}/${QuranText.asset}').readAsBytesSync();
      expect(utf8.decode(gzip.decode(out)), raw);
      // Sıkıştırılmış baytlar karşılaştırılmaz: zlib sürümü değişince
      // (CI'daki macOS) aynı içerik başka baytlara sıkışır. İçerik ve
      // kaynak notundaki özetler aynı olmalı.
      expect(
        File('${root.path}/assets/quran/SOURCE.txt').readAsStringSync(),
        File('assets/quran/SOURCE.txt').readAsStringSync(),
      );
    }, skip: _python ? false : 'python3 yok');

    test('eksik âyetli ya da telif bloğu silinmiş metni reddeder', () async {
      final lines = raw.split('\n');
      input.writeAsStringSync(
        lines.where((line) => !line.startsWith('2|255|')).join('\n'),
      );
      expect((await run()).exitCode, isNot(0));

      input.writeAsStringSync(
        lines.where((line) => !line.startsWith('#')).join('\n'),
      );
      expect((await run()).exitCode, isNot(0));
      expect(File('${root.path}/${QuranText.asset}').existsSync(), isFalse);
    }, skip: _python ? false : 'python3 yok');

    test('metinle tutmayan üst veriyi ve eksik meali reddeder', () async {
      input.writeAsStringSync(raw);
      // Bakara 286 değil 285 âyet diyen üst veri.
      meta.writeAsStringSync(rawMeta.replaceFirst('ayas="286"', 'ayas="285"'));
      expect((await run()).exitCode, isNot(0));
      // Bir sayfası eksik üst veri.
      meta.writeAsStringSync(
        rawMeta.replaceFirst('<page index="300"', '<!-- page index="300"'),
      );
      expect((await run()).exitCode, isNot(0));

      meta.writeAsStringSync(rawMeta);
      translation.writeAsStringSync(
        rawEnglish
            .split('\n')
            .where((line) => !line.startsWith('112|2|'))
            .join('\n'),
      );
      expect((await run()).exitCode, isNot(0));
      expect(File('${root.path}/${QuranText.asset}').existsSync(), isFalse);
    }, skip: _python ? false : 'python3 yok');
  });
}

/// Harekeler ve işaretler olmadan yalnızca harfler.
String _letters(String text) => text.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '');

final _python = () {
  try {
    return Process.runSync('python3', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
