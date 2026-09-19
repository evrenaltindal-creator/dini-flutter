import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/worship/domain/prayer_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arap harfleri bloğu (U+0600–U+06FF) ve Arapça ek formlar.
final _arabicScript = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿]');

/// Latin harfleri — Arapça alanında bulunmamalıdır.
final _latinLetters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]');

String _text(String languageCode, String key) =>
    AppLocalizations(Locale(languageCode)).text(key);

void main() {
  test('every recitation slot is declared and named', () {
    for (final id in RecitationId.values) {
      final recitation = recitationLibrary[id];
      expect(recitation, isNotNull, reason: '$id için kütüphanede kayıt yok.');
      expect(
        recitation!.nameKey.trim(),
        isNotEmpty,
        reason: '$id kaydının ad anahtarı boş.',
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

  test('transliteration is latin, never arabic script', () {
    for (final entry in recitationLibrary.entries) {
      final value = entry.value.transliteration;
      if (value.isEmpty) continue;
      expect(
        _arabicScript.hasMatch(value),
        isFalse,
        reason: '${entry.key} okunuş alanında Arap harfi var.',
      );
      expect(_latinLetters.hasMatch(value), isTrue);
    }
  });

  group('üç dilde metin', () {
    // Ad, anlam ve kaynak kullanıcıya görünür; CLAUDE.md üç dilde birlikte
    // eklenmelerini şart koşar. Eksik bir anahtar `text()` tarafından
    // anahtarın kendisi olarak döner, yani ekranda "recitation.x.name"
    // yazardı. Bu testler o sessiz düşüşü yakalar.
    for (final entry in recitationLibrary.entries) {
      final recitation = entry.value;
      if (!recitation.isComplete) continue;

      test('${entry.key} üç dilde de çözülüyor', () {
        for (final language in ['tr', 'en', 'ar']) {
          for (final key in [
            recitation.nameKey,
            recitation.meaningKey,
            recitation.sourceKey,
          ]) {
            final value = _text(language, key);
            expect(
              value,
              isNot(key),
              reason: '$language dilinde $key karşılıksız.',
            );
            expect(value.trim(), isNotEmpty);
          }
        }
      });
    }

    test('Türkçe ve İngilizce anlamlar Arap harfi taşımaz', () {
      // Anlam alanına yanlışlıkla Arapça metnin kendisi kopyalanırsa
      // kullanıcı çeviri yerine aynı metni ikinci kez görür.
      for (final entry in recitationLibrary.entries) {
        if (!entry.value.isComplete) continue;
        for (final language in ['tr', 'en']) {
          expect(
            _arabicScript.hasMatch(_text(language, entry.value.meaningKey)),
            isFalse,
            reason: '${entry.key} için $language anlamı Arap harfi içeriyor.',
          );
        }
      }
    });

    test('her kaynak künyesi bir kaynak adı taşır', () {
      // "Kaynak:" etiketinin arkası boş kalırsa kullanıcı içeriğin nereden
      // geldiğini göremez; dinî içerikte bu kabul edilemez.
      for (final entry in recitationLibrary.entries) {
        if (!entry.value.isComplete) continue;
        final turkish = _text('tr', entry.value.sourceKey);
        expect(
          turkish,
          anyOf(contains('Diyanet'), contains('Kur’an')),
          reason:
              '${entry.key} kaynağı tanınan bir kaynağa işaret etmiyor: '
              '$turkish',
        );
      }
    });
  });
}
