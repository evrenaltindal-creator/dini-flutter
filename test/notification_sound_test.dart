import 'dart:io';
import 'dart:typed_data';

import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/audio/presentation/opening_takbir.dart';
import 'package:dini_flutter/features/notifications/data/flutter_local_notification_service.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/data/notification_sound_installer.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

ByteData _bytes(int length) =>
    ByteData.view(Uint8List.fromList(List.filled(length, 7)).buffer);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bildirim sesi dosyaları', () {
    test('Android ham kaynağı derlemeye giriyor', () {
      // Bu dosya yokken kanal, var olmayan bir kaynağa işaret ediyordu:
      // kullanıcı "Uygulama tonu"nu seçiyor ama bildirim sessiz geliyordu.
      final raw = File(
        'android/app/src/main/res/raw/'
        '${NotificationSoundInstaller.androidResourceName}.wav',
      );
      expect(
        raw.existsSync(),
        isTrue,
        reason:
            'res/raw altında ses yok; Android kanalı geçersiz bir sese '
            'işaret eder.',
      );
      expect(raw.lengthSync(), greaterThan(1000));
    });

    test('yayın derlemesi bildirim seslerini silemez', () {
      // Kanal sesi adıyla çağırır; kaynak küçültücü bunu göremez ve keep.xml
      // olmadan dosyayı silerdi: bildirim sessiz gelirdi.
      final keep = File('android/app/src/main/res/raw/keep.xml')
          .readAsStringSync();
      final sounds = Directory('android/app/src/main/res/raw')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.wav'))
          .map((name) => name.substring(0, name.length - 4));
      expect(sounds, isNotEmpty);
      for (final sound in sounds) {
        expect(keep, contains('@raw/$sound'), reason: '$sound korunmuyor.');
      }
    });

    test('iOS için kopyalanacak varlık pubspec içinde bildirilmiş', () {
      expect(File(NotificationSoundInstaller.assetKey).existsSync(), isTrue);
      // assets/audio/ toplu olarak bildirilir; bildirilmezse kopyalama
      // çalışma anında sessizce başarısız olur.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/audio/'),
      );
    });
  });

  group('NotificationSoundInstaller', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('sounds'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('sesi hedef klasöre yazar', () async {
      final installer = NotificationSoundInstaller(
        loadAsset: (key) async {
          expect(key, NotificationSoundInstaller.assetKey);
          return _bytes(2048);
        },
        locateDirectory: () async => Directory('${temp.path}/Sounds'),
      );

      expect(await installer.install(), isTrue);
      final written = File(
        '${temp.path}/Sounds/${NotificationSoundInstaller.soundFileName}',
      );
      expect(written.existsSync(), isTrue);
      expect(written.lengthSync(), 2048);
    });

    test('dosya zaten yerindeyse yeniden yazmaz', () async {
      final target = Directory('${temp.path}/Sounds')..createSync();
      final file = File(
        '${target.path}/${NotificationSoundInstaller.soundFileName}',
      )..writeAsBytesSync(List.filled(2048, 0));
      final before = file.lastModifiedSync();

      var loads = 0;
      final installer = NotificationSoundInstaller(
        loadAsset: (_) async {
          loads++;
          return _bytes(2048);
        },
        locateDirectory: () async => target,
      );

      expect(await installer.install(), isTrue);
      expect(loads, 1, reason: 'Varlık yalnızca karşılaştırma için okunur.');
      expect(
        file.lastModifiedSync(),
        before,
        reason: 'Her açılışta 100 KB yeniden yazılmamalı.',
      );
    });

    test('boyut değişmişse yeniden yazar', () async {
      final target = Directory('${temp.path}/Sounds')..createSync();
      final file = File(
        '${target.path}/${NotificationSoundInstaller.soundFileName}',
      )..writeAsBytesSync(List.filled(10, 0));

      final installer = NotificationSoundInstaller(
        loadAsset: (_) async => _bytes(2048),
        locateDirectory: () async => target,
      );

      expect(await installer.install(), isTrue);
      expect(file.lengthSync(), 2048);
    });

    test('klasör gerekmeyen platformda hiçbir şey yapmaz', () async {
      // Android'de ses derlemeye girer; kopyalamaya gerek yoktur.
      var loads = 0;
      final installer = NotificationSoundInstaller(
        loadAsset: (_) async {
          loads++;
          return _bytes(1);
        },
        locateDirectory: () async => null,
      );

      expect(await installer.install(), isFalse);
      expect(loads, 0);
    });

    test('varlık okunamazsa hata sızdırmaz', () async {
      // Ses kurulamazsa bildirim sistem sesiyle çalmalı; kurulum hatası
      // bildirimlerin hiç planlanmamasına yol açmamalı.
      final installer = NotificationSoundInstaller(
        loadAsset: (_) async => throw PlatformException(code: 'missing'),
        locateDirectory: () async => Directory('${temp.path}/Sounds'),
      );

      expect(await installer.install(), isFalse);
    });
  });

  group('Android bildirim kanalları', () {
    test('her ses kendi kanalını alır', () {
      // Android 8+ bir kanalın sesini oluşturulduktan sonra değiştirmeye izin
      // vermez. Tek kanal kullanılsaydı kullanıcı ayarlardan sesi
      // değiştirdiğinde bildirim eski sesle çalmaya devam ederdi.
      final ids = {
        for (final sound in NotificationSound.values)
          FlutterLocalNotificationService.androidChannelFor(sound).id,
      };
      expect(
        ids,
        hasLength(NotificationSound.values.length),
        reason: 'İki ses aynı kanal kimliğini paylaşıyor: $ids',
      );
    });

    test('artık kullanılmayan eski kanal kimliği yeniden kurulmuyor', () {
      for (final sound in NotificationSound.values) {
        expect(
          FlutterLocalNotificationService.androidChannelFor(sound).id,
          isNot('dini_prayers'),
        );
      }
    });

    test('yalnızca uygulama tonu kanalı ham kaynağı gösterir', () {
      final tone = FlutterLocalNotificationService.androidChannelFor(
        NotificationSound.bundled,
      );
      expect(tone.sound, isNotNull);
      expect(tone.playSound, isTrue);

      final byDefault = FlutterLocalNotificationService.androidChannelFor(
        NotificationSound.defaultSound,
      );
      expect(byDefault.sound, isNull);
      expect(byDefault.playSound, isTrue);

      final silent = FlutterLocalNotificationService.androidChannelFor(
        NotificationSound.silent,
      );
      expect(silent.playSound, isFalse);
    });
  });

  group('ezan sesi', () {
    test('seslerin sırası kalıcı: yeni ses sona eklenir', () {
      // Tercih sıra numarasıyla saklanıyor. Araya bir ses eklenseydi kayıtlı
      // tercihler bir kayar, kullanıcının seçtiği ses sessizce değişirdi.
      expect(NotificationSound.values.map((sound) => sound.name).toList(), [
        'defaultSound',
        'bundled',
        'silent',
        'ezan',
      ]);
    });

    test('kayıt yoksa ezan seçimi telefonun sesine düşer', () {
      // Olmayan ham kaynağı gösteren kanal bildirimi SESSİZ çalardı.
      expect(
        FlutterLocalNotificationService.effectiveSound(
          NotificationSound.ezan,
          ezanAvailable: false,
        ),
        NotificationSound.defaultSound,
      );
      expect(
        FlutterLocalNotificationService.effectiveSound(
          NotificationSound.ezan,
          ezanAvailable: true,
        ),
        NotificationSound.ezan,
      );
      expect(
        FlutterLocalNotificationService.effectiveSound(
          NotificationSound.bundled,
          ezanAvailable: false,
        ),
        NotificationSound.bundled,
      );
    });

    test('ezan kendi kanalını ve iOS ses dosyasını kullanır', () {
      final channel = FlutterLocalNotificationService.androidChannelFor(
        NotificationSound.ezan,
      );
      expect(channel.sound, isNotNull);
      expect(channel.playSound, isTrue);
      expect(
        FlutterLocalNotificationService.iosSoundFor(NotificationSound.ezan),
        EzanSound.fileName,
      );
      expect(
        FlutterLocalNotificationService.iosSoundFor(
          NotificationSound.defaultSound,
        ),
        isNull,
      );
    });

    test('kaydın varlığı paketten okunur', () async {
      expect(
        await EzanSound.isAvailable(
          loadAsset: (_) async => throw Exception('yok'),
        ),
        isFalse,
      );
      expect(
        await EzanSound.isAvailable(loadAsset: (_) async => ByteData(1000)),
        isTrue,
      );
    });

    test('pakete giren kayıt lisanslı, 30 saniyeden kısa ve iki yerde', () {
      // Kayıt henüz yoksa bu test boş geçer; varsa kuralları bekçiler.
      // Telifi olan bir kayıt uygulamaya alınmaz.
      final asset = File(EzanSound.assetKey);
      if (!asset.existsSync()) return;

      final note = File('assets/audio/EZAN_SOURCE.txt');
      expect(note.existsSync(), isTrue, reason: 'Kaydın kaynağı yazılmamış.');
      final license = RegExp(
        r'^Lisans: (.+)$',
        multiLine: true,
      ).firstMatch(note.readAsStringSync());
      expect(license?.group(1)?.trim(), isNotEmpty, reason: 'Lisans yok.');

      // CC BY lisanslı kayıt atıfsız kullanılamaz: Hakkında sayfası kaydın
      // sahibini üç dilde yazmalı.
      if (license!.group(1)!.contains('CC BY')) {
        for (final code in ['tr', 'en', 'ar']) {
          final credit = AppLocalizations(Locale(code)).text('about.ezan');
          expect(credit, contains('CC BY'), reason: '$code atıf yok');
          expect(credit, contains('ismail demir'), reason: '$code sahip yok');
        }
      }

      final android = File('android/app/src/main/res/raw/ezan.wav');
      expect(android.existsSync(), isTrue);
      expect(android.readAsBytesSync(), asset.readAsBytesSync());

      final bytes = asset.readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      final byteRate = header.getUint32(28, Endian.little);
      var offset = 12;
      var dataSize = 0;
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = header.getUint32(offset + 4, Endian.little);
        if (id == 'data') {
          dataSize = size;
          break;
        }
        offset += 8 + size;
      }
      expect(
        dataSize / byteRate,
        lessThan(EzanSound.maxSeconds),
        reason: 'iOS 30 saniyeden uzun sesi çalmaz, varsayılana döner.',
      );

      // Kullanıcı isteği: ezanın ilk 5 saniyesi, normal sesle başlar ve
      // kısılarak biter.
      final samples = _samples(bytes);
      final rate = header.getUint32(24, Endian.little);
      final channels = header.getUint16(22, Endian.little);
      expect(samples.length / channels / rate, closeTo(5, .05));
      int peak(Iterable<int> values) =>
          values.fold(0, (max, v) => v.abs() > max ? v.abs() : max);
      final firstSecond = peak(samples.take(rate * channels));
      final lastTenth = peak(
        samples.skip(samples.length - rate * channels ~/ 10),
      );
      expect(firstSecond, greaterThan(8000), reason: 'Başı sessiz kalmış.');
      expect(lastTenth, lessThan(firstSecond ~/ 20), reason: 'Kesik bitiyor.');
    });
  });

  group('açılış sesi', () {
    test('ezan kaydı varsa açılışta tekbir değil ezan çalar', () {
      final ezan = openingSoundFor(ezanAvailable: true);
      // audioplayers AssetSource yolu `assets/` önekini kendisi ekler.
      expect('assets/${ezan.asset}', EzanSound.assetKey);
      expect(
        ezan.volume,
        1.0,
        reason:
            'Ezan normal sesle başlamalı; kısılma dosyanın içindedir '
            '(tool/prepare_ezan_sound.py).',
      );
    });

    test('kayıt yokken eski kısık tekbir kalır', () {
      final takbir = openingSoundFor(ezanAvailable: false);
      expect(takbir.asset, 'audio/opening_takbir.mp3');
      expect(File('assets/${takbir.asset}').existsSync(), isTrue);
      expect(takbir.volume, lessThan(.5));
    });
  });

  group('ezan hazırlama betiği', () {
    // Betik lisanssız kayıt kabul etmemeli ve klibi "önce normal ses, sonra
    // kısılarak biter" biçiminde yazmalı.
    late Directory root;
    late File input;
    const rate = 8000;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ezan');
      input = File('${root.path}/kayit.wav');
      // 12 saniyelik sabit genlikli bir ton: kısılma ancak betikten gelir.
      final samples = Int16List(rate * 12);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = i.isEven ? 6000 : -6000;
      }
      input.writeAsBytesSync(_wav(samples, rate));
    });
    tearDown(() => root.deleteSync(recursive: true));

    Future<ProcessResult> run(List<String> extra) => Process.run('python3', [
      'tool/prepare_ezan_sound.py',
      input.path,
      '--root',
      root.path,
      ...extra,
    ]);

    test('ilk 5 saniye: normal başlar, kısılarak sessize iner', () async {
      final result = await run(['--source', 'deneme', '--license', 'CC0']);
      expect(result.exitCode, 0, reason: '${result.stderr}');

      final asset = File('${root.path}/${EzanSound.assetKey}');
      final android = File(
        '${root.path}/android/app/src/main/res/raw/ezan.wav',
      );
      expect(android.readAsBytesSync(), asset.readAsBytesSync());

      final samples = _samples(asset.readAsBytesSync());
      expect(samples.length / rate, closeTo(5, .01));

      int peakAt(double second) {
        final start = (second * rate).round();
        var peak = 0;
        for (var i = start; i < start + 200 && i < samples.length; i++) {
          peak = samples[i].abs() > peak ? samples[i].abs() : peak;
        }
        return peak;
      }

      final full = peakAt(0);
      expect(
        full,
        greaterThan(20000),
        reason: 'Ses normal seviyede başlamalı.',
      );
      expect(peakAt(1.5), full, reason: 'İlk kısım kısılmamalı.');
      expect(peakAt(3), lessThan(full));
      expect(peakAt(4), lessThan(peakAt(3)));
      expect(samples.last.abs(), lessThan(50), reason: 'Kesik bitmemeli.');

      final note = File('${root.path}/assets/audio/EZAN_SOURCE.txt');
      expect(note.readAsStringSync(), contains('Lisans: CC0'));
    }, skip: _python ? false : 'python3 yok');

    test('--start auto baştaki sessizliği atlar', () async {
      // Gerçek kayıt 5,7 saniye sessizlikle başlıyordu; "ilk 5 saniye"
      // alınsaydı açılışta hiçbir şey duyulmazdı.
      final samples = Int16List(rate * 12);
      for (var i = rate * 3; i < samples.length; i++) {
        samples[i] = i.isEven ? 6000 : -6000;
      }
      input.writeAsBytesSync(_wav(samples, rate));
      final result = await run([
        '--start',
        'auto',
        '--source',
        'deneme',
        '--license',
        'CC0',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final clip = _samples(
        File('${root.path}/${EzanSound.assetKey}').readAsBytesSync(),
      );
      // Ses, klibin ilk saniyesinin içinde başlar.
      final firstLoud = clip.indexWhere((v) => v.abs() > 10000);
      expect(firstLoud, inInclusiveRange(0, rate ~/ 5));
      final note = File('${root.path}/assets/audio/EZAN_SOURCE.txt')
          .readAsStringSync();
      expect(note, contains('Başlangıç: kaydın 2.90. saniyesi'));
    }, skip: _python ? false : 'python3 yok');

    test('lisans ya da kaynak verilmeden kayıt alınmaz', () async {
      final noLicense = await run(['--source', 'deneme', '--license', ' ']);
      expect(noLicense.exitCode, isNot(0));
      final noSource = await run(['--source', ' ', '--license', 'CC0']);
      expect(noSource.exitCode, isNot(0));
      expect(File('${root.path}/${EzanSound.assetKey}').existsSync(), isFalse);
    }, skip: _python ? false : 'python3 yok');
  });

  test('bozuk ya da ileri sürümden kalan ses kaydı çökertmez', () async {
    final storage = _EzanMemoryStorage()
      ..values['dini.notifications.sound'] = '99';
    final preferences = await NotificationPreferencesRepository(storage).load();
    expect(preferences.sound, NotificationSound.defaultSound);
  });
}

class _EzanMemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

final _python = () {
  try {
    return Process.runSync('python3', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// 16 bit tek kanallı PCM WAV.
Uint8List _wav(Int16List samples, int rate) {
  final data = samples.buffer.asUint8List();
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // RIFF
    ..setUint32(4, 36 + data.length, Endian.little)
    ..setUint32(8, 0x57415645) // WAVE
    ..setUint32(12, 0x666d7420) // fmt
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // data
    ..setUint32(40, data.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
}

Int16List _samples(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      return Int16List.fromList([
        for (var i = 0; i < size ~/ 2; i++)
          view.getInt16(offset + 8 + i * 2, Endian.little),
      ]);
    }
    offset += 8 + size;
  }
  throw StateError('data yok');
}
