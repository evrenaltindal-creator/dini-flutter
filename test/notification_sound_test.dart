import 'dart:io';
import 'dart:typed_data';

import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/notifications/data/flutter_local_notification_service.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/data/notification_sound_installer.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:flutter/services.dart';
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
    });
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
