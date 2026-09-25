import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Varlık paketinden bayt okuyan işlev. Testlerde değiştirilir.
typedef AssetBytesLoader = Future<ByteData> Function(String key);

/// Varsayılan okuyucu. `rootBundle.load` bir örnek yöntemi olduğu için sabit
/// ifadede kullanılamaz; üst düzey bir işlev olarak sarmalanır.
Future<ByteData> loadFromRootBundle(String key) => rootBundle.load(key);

/// Seslerin kopyalanacağı klasörü bulan işlev. Bu platformda bir klasör
/// gerekmiyorsa null döner.
typedef SoundDirectoryLocator = Future<Directory?> Function();

/// iOS'ta bildirim sesini uygulama kabına kurar.
///
/// iOS bildirim sesini yalnızca iki yerde arar: uygulama paketinin kökü ve
/// kabın `Library/Sounds` klasörü. Flutter varlıkları ikisinde de değildir;
/// `App.framework` içinde durur. Bu yüzden ses ilk açılışta varlıklardan
/// `Library/Sounds` altına kopyalanır.
///
/// Android'e dokunmaz: orada ses `res/raw/notification_tone.wav` olarak
/// derlemeye girer ve kopyalamaya gerek yoktur.
class NotificationSoundInstaller {
  /// Sesin varlık paketindeki anahtarı.
  static const assetKey = 'assets/audio/notification_tone.wav';

  /// iOS'un bildirim tanımında beklediği dosya adı.
  static const soundFileName = 'notification_tone.wav';

  /// Android'de bildirim kanalının gösterdiği ham kaynak adı (uzantısız).
  static const androidResourceName = 'notification_tone';

  final AssetBytesLoader loadAsset;
  final SoundDirectoryLocator locateDirectory;

  /// Kopyalanacak varlık ve iOS'taki dosya adı. Varsayılan uygulama tonudur;
  /// ezan için [NotificationSoundInstaller.ezan].
  final String sourceAsset;
  final String targetFileName;

  const NotificationSoundInstaller({
    this.loadAsset = loadFromRootBundle,
    this.locateDirectory = defaultSoundDirectory,
    this.sourceAsset = assetKey,
    this.targetFileName = soundFileName,
  });

  /// Ezan sesini kuran örnek.
  const NotificationSoundInstaller.ezan({
    this.loadAsset = loadFromRootBundle,
    this.locateDirectory = defaultSoundDirectory,
  }) : sourceAsset = EzanSound.assetKey,
       targetFileName = EzanSound.fileName;

  /// Sesi yerine kopyalar ve kurulup kurulmadığını döner.
  ///
  /// Hiçbir hata dışarı sızmaz: ses kurulamazsa bildirim sistem sesiyle
  /// çalar. Bildirimin hiç kurulmaması, sesinin yanlış olmasından kötüdür.
  Future<bool> install() async {
    try {
      final directory = await locateDirectory();
      if (directory == null) return false;

      final bytes = (await loadAsset(sourceAsset)).buffer.asUint8List();
      final target = File('${directory.path}/$targetFileName');

      // Aynı dosya zaten yerindeyse diske yazma. Kurulum her açılışta
      // çalışır; her seferinde 100 KB yazmak gereksizdir.
      if (target.existsSync() && target.lengthSync() == bytes.length) {
        return true;
      }

      await directory.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// iOS'ta `Library/Sounds`, diğer platformlarda null.
  static Future<Directory?> defaultSoundDirectory() async {
    if (!Platform.isIOS) return null;
    final library = await getLibraryDirectory();
    return Directory('${library.path}/Sounds');
  }
}

/// Ezan bildirim sesi.
///
/// Kayıt dosyası depoya BİLEREK konmadı: telifi netleşmemiş bir kayıt
/// uygulamaya alınmaz. Lisansı belli bir kayıt geldiğinde
/// `tool/prepare_ezan_sound.py` ilk 5 saniyesini alıp sonunu kısar, buraya
/// ve Android'in `res/raw` klasörüne yazar; seçenek o zaman görünür ve
/// açılış tekbirinin yerine de bu ses çalar.
class EzanSound {
  static const assetKey = 'assets/audio/ezan.wav';
  static const fileName = 'ezan.wav';
  static const androidResourceName = 'ezan';

  /// iOS bildirim sesini en fazla 30 saniye çalar; daha uzun dosyada
  /// sessizce varsayılan sese döner.
  static const maxSeconds = 30;

  /// Kayıt pakette var mı?
  static Future<bool> isAvailable({
    AssetBytesLoader loadAsset = loadFromRootBundle,
  }) async {
    try {
      final data = await loadAsset(assetKey);
      return data.lengthInBytes > 44; // WAV başlığından büyük
    } catch (_) {
      return false;
    }
  }
}
