import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// App Store mağaza sayfası (`store/`) Apple'ın sınırlarına uymalı; aksi
/// hâlde yükleme ya da inceleme başvurusu reddedilir.
void main() {
  /// PNG başlığından genişlik ve yükseklik.
  (int, int) pngSize(File file) {
    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: file.path);
    return (data.getUint32(16), data.getUint32(20));
  }

  final locales = Directory('store/metadata')
      .listSync()
      .whereType<Directory>()
      .map((dir) => dir.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList();

  test('mağaza dilleri var', () {
    // ar-SA Arapça aramalar içindir; en-GB'yi Türkiye mağazası Türkçe ile
    // birlikte arar (İngilizce aramalar).
    expect(locales, containsAll(['tr', 'en-US', 'ar-SA', 'en-GB']));
  });

  for (final locale in locales) {
    group(locale, () {
      String read(String name) =>
          File('store/metadata/$locale/$name.txt').readAsStringSync();

      test('karakter sınırları', () {
        expect(read('subtitle').length, inInclusiveRange(1, 30));
        // Türkçe sayfanın adı App Store Connect'teki uygulama adıdır; yeni
        // dillerin adı (tekil olmalı) name.txt'den gelir.
        final name = File('store/metadata/$locale/name.txt');
        if (name.existsSync()) {
          expect(name.readAsStringSync().length, inInclusiveRange(2, 30));
        } else {
          expect(locale, 'tr', reason: 'yeni mağaza dili name.txt ister');
        }
        expect(read('keywords').length, inInclusiveRange(1, 100));
        expect(read('promotional_text').length, inInclusiveRange(1, 170));
        expect(read('description').length, inInclusiveRange(1, 4000));
        // Anahtar kelimelerde boşluk yer kaplar ve işe yaramaz.
        expect(read('keywords'), isNot(contains(', ')));
      });

      test('destek ve gizlilik adresi depodaki sayfaları gösterir', () {
        // Sayfalar vardiox-legal deposunun GitHub Pages'inde yayında; kaynağı
        // bu depodaki docs/ klasörüdür.
        const base =
            'https://evrenaltindal-creator.github.io/vardiox-legal/namaz-yolu/';
        for (final (file, page) in [
          ('support_url', 'support'),
          ('privacy_url', 'privacy'),
        ]) {
          expect(read(file), '$base$page/');
          expect(File('docs/$page/index.html').existsSync(), isTrue);
        }
      });

      test('pazarlama adresi ewocom.com tanıtım sayfasıdır', () {
        // Sayfanın kaynağı docs/ewocom/ (sitenin kendi kalıbıyla).
        expect(read('marketing_url'), 'https://ewocom.com/namaz-yolu/');
        expect(File('docs/ewocom/namaz-yolu/index.html').existsSync(), isTrue);
      });

      test('bu sürümde olmayan özellik vaat edilmez', () {
        // Premium ilk sürümde kaldırıldı (kullanıcı kararı).
        expect(read('description').toLowerCase(), isNot(contains('premium')));
      });
    });
  }

  test('iPhone görselleri 6,9 inç boyutunda ve kaynakları var', () {
    final shots = Directory('store/screenshots/tr')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList();
    expect(shots.length, inInclusiveRange(3, 10));
    for (final shot in shots) {
      expect(pngSize(shot), (1320, 2868), reason: shot.path);
      final name = shot.uri.pathSegments.last.replaceFirst(
        RegExp(r'^iphone-\d\d-'),
        '',
      );
      final raw = File(
        'store/screenshots/raw/tr/${name.replaceAll('.png', '.jpg')}',
      );
      expect(raw.existsSync(), isTrue, reason: '${raw.path} yok');
    }
  });

  test('gizlilik sayfası uygulamanın gerçekte yaptığını söyler', () {
    final page = File('docs/privacy/index.html').readAsStringSync();
    // Üç dil de var.
    for (final id in ['id="tr"', 'id="en"', 'id="ar"']) {
      expect(page, contains(id));
    }
    expect(page, contains('info@ewocom.com'));
    // Konum cihazdan çıkmaz (CLAUDE.md, değişmez kural 2).
    expect(page, contains('hiçbir sunucuya gönderilmez'));
  });

  test(
    'ewocom tanıtım sayfası sitenin kalıbını korur, doğru uygulamayı açar',
    () {
      final page = File('docs/ewocom/namaz-yolu/index.html').readAsStringSync();
      // Kullanıcı: "sayfa yapısını bozma sakın." Sitenin başlığı, alt bilgisi,
      // stil dosyası ve betiği aynen durur.
      for (final part in [
        '<header class="global-header">',
        '<footer class="global-footer">',
        'href="/assets/styles.css"',
        'src="/assets/site.js"',
        'class="product-detail-hero prayer-detail-hero"',
      ]) {
        expect(page, contains(part));
      }
      expect(page, contains('https://apps.apple.com/tr/app/id6805668631'));
      // Sayfadaki her yerel görsel pakette ya da sitede zaten var.
      final siteAssets = {
        '/assets/ewocom-logo.png',
        '/assets/namaz-yolu-icon.png',
        '/assets/namaz-yolu-hero.png',
      };
      for (final match in RegExp(r'src="(/assets/[^"]+)"').allMatches(page)) {
        final path = match.group(1)!;
        if (siteAssets.contains(path) || path.endsWith('.js')) continue;
        expect(File('docs/ewocom$path').existsSync(), isTrue, reason: path);
      }
      // Premium yok; olmayan özellik vaat edilmez.
      expect(page.toLowerCase(), isNot(contains('premium')));
    },
  );
}
