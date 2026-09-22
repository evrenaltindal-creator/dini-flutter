import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Namaz hocasının duaları sesli okuması.
///
/// Telefonun kendi konuşma motoru kullanılır (iOS AVSpeechSynthesizer,
/// Android TextToSpeech): hiçbir şey internete gitmez, kayıt paketlenmez.
/// Bu bir yapay sestir ve tecvidli okuyuş değildir; ekranda bu açıkça
/// söylenir. Lisanslı insan kaydı geldiğinde bu arayüzün başka bir
/// uygulaması yazılır, sayfa değişmez.
abstract class PrayerVoice {
  /// Sesi hazırlar; telefonda Arapça ses yoksa false döner.
  Future<bool> prepare();

  /// [text] bitene kadar bekler. [speed] 1 normal, 2 iki kat hızlı.
  Future<void> speak(String text, {required double speed});

  Future<void> stop();
}

/// Uygulamanın hız çarpanını konuşma motorunun hızına çevirir.
///
/// flutter_tts iki platformda da 0,5'i "normal" sayar. Dua tane tane
/// okunsun diye 1× biraz daha ağırdır.
double speechRateFor(double speed) => (.42 * speed).clamp(.1, 1.0);

class DeviceArabicVoice implements PrayerVoice {
  FlutterTts? _tts;
  Future<bool>? _ready;

  @override
  Future<bool> prepare() => _ready ??= _prepare();

  Future<bool> _prepare() async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Kullanıcı sesli okumayı kendisi açtı: telefon sessizdeyken de
        // duyulmalı. Çalan müzik kesilmez, kısılır.
        await tts.setSharedInstance(true);
        await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ]);
      }
      for (final language in ['ar-SA', 'ar']) {
        if (await tts.isLanguageAvailable(language) == true) {
          await tts.setLanguage(language);
          _tts = tts;
          return true;
        }
      }
      return false;
    } catch (_) {
      // Konuşma motoru olmayan cihaz ya da test ortamı.
      return false;
    }
  }

  @override
  Future<void> speak(String text, {required double speed}) async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.setSpeechRate(speechRateFor(speed));
      await tts.speak(text);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

final prayerVoiceProvider = Provider<PrayerVoice>((ref) => DeviceArabicVoice());
