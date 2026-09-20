import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Uygulama simgesi App Store'un reddettiği hatalarla yayına çıkmasın diye
/// dosyaların kendisini okur.
///
/// Depoda uzun süre varsayılan Flutter logosu durdu; hiçbir test bunu
/// yakalamıyordu çünkü simge Dart kodundan hiç geçmiyor. Bu test PNG
/// başlıklarını doğrudan okur.
const _iosIconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// PNG başlığından (IHDR) genişlik, yükseklik ve renk tipi.
({int width, int height, int colorType}) _header(File file) {
  final bytes = file.readAsBytesSync();
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < signature.length; i++) {
    expect(bytes[i], signature[i], reason: '${file.path} bir PNG değil.');
  }
  int at(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  // IHDR: 8 imza + 4 uzunluk + 4 tip, ardından genişlik ve yükseklik.
  return (width: at(16), height: at(20), colorType: bytes[25]);
}

/// PNG renk tipinin alfa kanalı taşıyıp taşımadığı. 4 gri+alfa, 6 RGBA.
bool _hasAlpha(int colorType) => colorType == 4 || colorType == 6;

/// 8 bit derinlikli, aralıksız (non-interlaced) bir PNG'nin tek pikselini okur.
///
/// Uygulamanın kendi ürettiği simgeler her zaman bu biçimdedir; başka bir
/// biçimle karşılaşırsak test anlamlı bir mesajla düşer.
List<int> _pixelAt(File file, int x, int y) {
  final bytes = file.readAsBytesSync();
  final header = _header(file);
  expect(
    bytes[24],
    8,
    reason: '${file.path}: yalnızca 8 bit derinlik çözülebiliyor.',
  );
  expect(bytes[28], 0, reason: '${file.path}: aralıklı PNG çözülemiyor.');
  final channels = switch (header.colorType) {
    0 => 1,
    2 => 3,
    4 => 2,
    6 => 4,
    _ => fail('${file.path}: beklenmeyen renk tipi ${header.colorType}.'),
  };

  // IDAT parçalarını birleştir. Parça sırası: uzunluk, tip, veri, CRC.
  final compressed = <int>[];
  var offset = 8;
  while (offset < bytes.length) {
    final length =
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (type == 'IDAT') {
      compressed.addAll(bytes.sublist(offset + 8, offset + 8 + length));
    }
    offset += 12 + length;
  }

  final raw = ZLibDecoder().convert(compressed);
  final stride = header.width * channels;
  // Filtre çözümü önceki satıra bağlıdır; istenen satıra kadar hepsini kur.
  var previous = List<int>.filled(stride, 0);
  var current = List<int>.filled(stride, 0);
  for (var row = 0; row <= y; row++) {
    final start = row * (stride + 1);
    final filter = raw[start];
    current = List<int>.filled(stride, 0);
    for (var i = 0; i < stride; i++) {
      final value = raw[start + 1 + i];
      final left = i >= channels ? current[i - channels] : 0;
      final up = previous[i];
      final upLeft = i >= channels ? previous[i - channels] : 0;
      current[i] = switch (filter) {
        0 => value,
        1 => (value + left) & 0xff,
        2 => (value + up) & 0xff,
        3 => (value + ((left + up) >> 1)) & 0xff,
        4 => (value + _paeth(left, up, upLeft)) & 0xff,
        _ => fail('${file.path}: bilinmeyen filtre $filter.'),
      };
    }
    previous = current;
  }
  return current.sublist(x * channels, x * channels + channels);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

void main() {
  group('iOS uygulama simgesi', () {
    final folder = Directory(_iosIconSet);
    final contents = jsonDecode(
      File('$_iosIconSet/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final images = (contents['images'] as List).cast<Map<String, dynamic>>();

    test('Contents.json içindeki her dosya var ve boyutu doğru', () {
      expect(folder.existsSync(), isTrue);
      for (final image in images) {
        final filename = image['filename'] as String?;
        expect(
          filename,
          isNotNull,
          reason:
              'Contents.json içinde dosyasız bir '
              'kayıt var: $image',
        );
        final file = File('$_iosIconSet/$filename');
        expect(
          file.existsSync(),
          isTrue,
          reason: '$filename Contents.json içinde geçiyor ama dosya yok.',
        );

        final points = double.parse((image['size'] as String).split('x').first);
        final scale = double.parse(
          (image['scale'] as String).replaceAll('x', ''),
        );
        final expected = (points * scale).round();
        final header = _header(file);
        expect(
          [header.width, header.height],
          [expected, expected],
          reason:
              '$filename ${expected}x$expected olmalı, '
              '${header.width}x${header.height} bulundu. Yanlış boyuttaki '
              'simge App Store yüklemesinde reddedilir.',
        );
      }
    });

    test('hiçbir simgede alfa kanalı yok', () {
      // App Store Connect saydamlık içeren simgeleri reddeder; bu, yüklemeden
      // önce yakalanmazsa bir sürüm turu kaybettirir.
      for (final image in images) {
        final file = File('$_iosIconSet/${image['filename']}');
        expect(
          _hasAlpha(_header(file).colorType),
          isFalse,
          reason: '${image['filename']} alfa kanalı taşıyor.',
        );
      }
    });

    test('varsayılan Flutter simgesi değil', () {
      // Flutter şablonunun simgesi beyaz zeminlidir: köşe pikseli saf beyaza
      // çok yakındır. Bizimki koyu yeşil bir zemindir. Bu, "simgeyi değiştirmeyi
      // unuttuk" durumunu yakalayan asıl kontroldür.
      final file = File('$_iosIconSet/Icon-App-1024x1024@1x.png');
      for (final corner in [(4, 4), (1019, 4), (4, 1019), (1019, 1019)]) {
        final pixel = _pixelAt(file, corner.$1, corner.$2);
        final brightness = pixel.take(3).reduce((a, b) => a + b) / 3;
        expect(
          brightness,
          lessThan(120),
          reason:
              'Simgenin ${corner.$1},${corner.$2} köşesi açık renkli '
              '($pixel). Varsayılan Flutter simgesi hâlâ yerinde olabilir.',
        );
      }
    });
  });

  group('Android başlatıcı simgesi', () {
    const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
    const legacySizes = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };

    test('her yoğunlukta eski ve uyarlanabilir katmanlar var', () {
      for (final density in densities) {
        final legacy = File(
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        );
        expect(legacy.existsSync(), isTrue, reason: '$density eksik.');
        final header = _header(legacy);
        expect(header.width, legacySizes[density]);

        final foreground = File(
          'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png',
        );
        expect(
          foreground.existsSync(),
          isTrue,
          reason:
              'Uyarlanabilir simgenin ön planı $density için yok; Android 8+ '
              'cihazlarda simge beyaz bir kutu içinde görünür.',
        );
        // Ön plan 108dp tuval ister ve saydam olmalıdır.
        expect(
          foreground.existsSync() ? _header(foreground).width : 0,
          (legacySizes[density]! * 108 / 48).round(),
        );
        expect(_hasAlpha(_header(foreground).colorType), isTrue);
      }
    });

    test('uyarlanabilir simge tanımı degrade zemin katmanını gösterir', () {
      // Zemin artık düz renk değil: tasarımın zemini degrade ve düz renk
      // katman, küçültülen ön planın kenarında renk farkı bırakıyordu.
      for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
        final definition = File(
          'android/app/src/main/res/mipmap-anydpi-v26/$name',
        );
        expect(definition.existsSync(), isTrue, reason: '$name yok.');
        final xml = definition.readAsStringSync();
        expect(
          xml,
          contains('@mipmap/ic_launcher_background'),
          reason: '$name düz renk zemine dönmüş.',
        );
        expect(xml, contains('@mipmap/ic_launcher_foreground'));
      }
    });

    test('her yoğunlukta zemin katmanı da var', () {
      // Tanım olmayan bir çizime işaret ederse derleme kırılır.
      for (final density in densities) {
        final background = File(
          'android/app/src/main/res/mipmap-$density/ic_launcher_background.png',
        );
        expect(
          background.existsSync(),
          isTrue,
          reason: '$density için zemin katmanı üretilmemiş.',
        );
      }
    });
  });
}
