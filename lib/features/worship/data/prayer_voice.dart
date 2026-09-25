import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Telefondaki Arapça sesin durumu.
enum VoiceReadiness {
  /// Arapça ses yok; dualar yalnızca yazılı gösterilir.
  unavailable,

  /// Yalnızca telefonun temel (robotik) sesi var; daha iyisi indirilebilir.
  basic,

  /// Gelişmiş ya da yüksek kaliteli ses kullanılıyor.
  natural,
}

/// Namaz hocasının duaları sesli okuması.
///
/// Telefonun kendi konuşma motoru kullanılır (iOS AVSpeechSynthesizer,
/// Android TextToSpeech): hiçbir şey internete gitmez, kayıt paketlenmez.
/// Bu bir yapay sestir ve tecvidli okuyuş değildir; ekranda bu açıkça
/// söylenir. Lisanslı insan kaydı geldiğinde bu arayüzün başka bir
/// uygulaması yazılır, sayfa değişmez.
abstract class PrayerVoice {
  /// Sesi hazırlar ve ne kadar iyi olduğunu söyler.
  Future<VoiceReadiness> prepare();

  /// [text] bitene kadar bekler. [speed] 1 normal, 2 iki kat hızlı.
  Future<void> speak(String text, {required double speed});

  Future<void> stop();
}

/// Uygulamanın hız çarpanını konuşma motorunun hızına çevirir.
///
/// flutter_tts iki platformda da 0,5'i "normal" sayar. Dua tane tane
/// okunsun diye 1× biraz daha ağırdır.
double speechRateFor(double speed) => (.42 * speed).clamp(.1, 1.0);

/// Satırlar (âyetler) arasındaki soluk. Metin tek nefeste okunursa dua
/// değil duyuru gibi gelir.
Duration linePauseFor(double speed) =>
    Duration(milliseconds: (450 / speed.clamp(.25, 4)).round());

/// Kalite adı → sıra. iOS "default/enhanced/premium", Android "very low …
/// very high" verir.
const _qualityRank = {
  'premium': 5,
  'very high': 5,
  'enhanced': 4,
  'high': 4,
  'default': 2,
  'normal': 2,
  'low': 1,
  'very low': 0,
};

/// Telefonun seslerinden en iyi Arapça sesi seçer.
///
/// İnternet isteyen sesler ALINMAZ: onlar metni uzaktaki sunucuya gönderir
/// (uygulama hiçbir şeyi dışarı göndermez). İndirilmemiş sesler de
/// alınmaz; seçilirse hiç ses çıkmaz. Eşitlikte Suudi Arapçası (ar-SA)
/// önce gelir: Kur'an okunuşuna en yakın telaffuz odur.
Map<String, String>? pickArabicVoice(Iterable<Map<String, String>> voices) {
  Map<String, String>? best;
  var bestScore = -1;
  for (final voice in voices) {
    final locale = (voice['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    if (!locale.startsWith('ar')) continue;
    if (voice['network_required'] == '1') continue;
    if ((voice['features'] ?? '').contains('notInstalled')) continue;
    final quality = _qualityRank[voice['quality']] ?? 2;
    final score = quality * 10 + (locale == 'ar-sa' ? 1 : 0);
    if (score > bestScore) {
      best = voice;
      bestScore = score;
    }
  }
  return best;
}

VoiceReadiness readinessOf(Map<String, String>? voice) {
  if (voice == null) return VoiceReadiness.unavailable;
  final quality = _qualityRank[voice['quality']] ?? 2;
  return quality >= 4 ? VoiceReadiness.natural : VoiceReadiness.basic;
}

class DeviceArabicVoice implements PrayerVoice {
  FlutterTts? _tts;
  Future<VoiceReadiness>? _ready;
  int _run = 0;

  @override
  Future<VoiceReadiness> prepare() => _ready ??= _prepare();

  Future<VoiceReadiness> _prepare() async {
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
      final raw = await tts.getVoices;
      final voices = [
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              {
                for (final entry in item.entries)
                  '${entry.key}': '${entry.value}',
              },
      ];
      final voice = pickArabicVoice(voices);
      if (voice != null) {
        await tts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? '',
          if (voice['identifier'] != null) 'identifier': voice['identifier']!,
        });
        _tts = tts;
        return readinessOf(voice);
      }
      // Ses listesi boş gelen motorlar da var: dil adıyla dene.
      for (final language in ['ar-SA', 'ar']) {
        if (await tts.isLanguageAvailable(language) == true) {
          await tts.setLanguage(language);
          _tts = tts;
          return VoiceReadiness.basic;
        }
      }
      return VoiceReadiness.unavailable;
    } catch (_) {
      // Konuşma motoru olmayan cihaz ya da test ortamı.
      return VoiceReadiness.unavailable;
    }
  }

  @override
  Future<void> speak(String text, {required double speed}) async {
    final tts = _tts;
    if (tts == null) return;
    final run = _run;
    try {
      await tts.setSpeechRate(speechRateFor(speed));
      final lines = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      for (final (index, line) in lines.indexed) {
        if (run != _run) return; // durduruldu
        await tts.speak(line);
        if (index < lines.length - 1) {
          await Future<void>.delayed(linePauseFor(speed));
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _run++;
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

final prayerVoiceProvider = Provider<PrayerVoice>((ref) => DeviceArabicVoice());
