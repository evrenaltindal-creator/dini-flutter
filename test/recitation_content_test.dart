import 'package:dini_flutter/features/worship/domain/prayer_flow.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arap harfleri bloğu (U+0600–U+06FF) ve Arapça ek formlar.
final _arabicScript = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿]');

/// Latin harfleri — Arapça alanında bulunmamalıdır.
final _latinLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]');

void main() {
  test('every recitation slot is declared and named', () {
    for (final id in RecitationId.values) {
      final recitation = recitationLibrary[id];
      expect(recitation, isNotNull, reason: '$id için kütüphanede kayıt yok.');
      expect(
        recitation!.name.trim(),
        isNotEmpty,
        reason: '$id kaydının adı boş.',
      );
    }
  });

  test('no recitation ships without a source', () {
    for (final entry in recitationLibrary.entries) {
      expect(
        entry.value.isMissingSource,
        isFalse,
        reason:
            '${entry.key} için metin girilmiş ama kaynak belirtilmemiş. '
            'Dini içerik kaynaksız yayına çıkamaz.',
      );
    }
  });

  test('a recitation is either fully empty or fully filled', () {
    for (final entry in recitationLibrary.entries) {
      expect(
        entry.value.isPartial,
        isFalse,
        reason:
            '${entry.key} yarım kalmış. Arapça metin, okunuş, anlam ve kaynak '
            'birlikte doldurulmalıdır; eksik metin kullanıcıyı yanıltır.',
      );
    }
  });

  test('the arabic field really holds arabic script', () {
    for (final entry in recitationLibrary.entries) {
      final arabic = entry.value.arabic;
      if (arabic.isEmpty) continue;
      expect(
        _arabicScript.hasMatch(arabic),
        isTrue,
        reason:
            '${entry.key} için "arabic" alanı Arap harfi içermiyor. '
            'Okunuş yanlışlıkla bu alana yazılmış olabilir.',
      );
      expect(
        _latinLetters.hasMatch(arabic),
        isFalse,
        reason:
            '${entry.key} için "arabic" alanında Latin harfi var. '
            'Okunuş metni ayrı alana yazılmalıdır.',
      );
    }
  });

  test('transliteration and meaning are not swapped with arabic', () {
    for (final entry in recitationLibrary.entries) {
      final value = entry.value;
      if (value.transliteration.isNotEmpty) {
        expect(
          _arabicScript.hasMatch(value.transliteration),
          isFalse,
          reason: '${entry.key} okunuş alanında Arap harfi var.',
        );
      }
      if (value.meaning.isNotEmpty) {
        expect(
          _arabicScript.hasMatch(value.meaning),
          isFalse,
          reason: '${entry.key} anlam alanında Arap harfi var.',
        );
      }
    }
  });
}
