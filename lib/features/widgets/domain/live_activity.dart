import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../shared/models/domain.dart';

/// Kilit ekranında ve Dynamic Island'da gösterilen sıradaki vakit.
///
/// **Metinler Dart tarafında çevrilir.** Uzantının uygulamanın çeviri
/// haritasına erişimi yok; vakit adı ve konum adı hazır metin olarak gönderilir
/// (widget anlık görüntüsünde de aynı yol izleniyor). Aksi halde kilit ekranı
/// uygulamanın dilinden bağımsız, hep İngilizce görünürdü.
class LiveActivityState {
  /// Sıradaki vakit.
  final Prayer prayer;

  /// Vaktin girdiği an.
  final DateTime prayerTime;

  /// Kullanıcının dilinde vakit adı.
  final String prayerLabel;

  /// Gösterilecekse konum adı.
  final String? locationName;

  const LiveActivityState({
    required this.prayer,
    required this.prayerTime,
    required this.prayerLabel,
    this.locationName,
  });

  Map<String, dynamic> toJson() => {
    'prayer': prayer.name,
    'prayerTime': prayerTime.toIso8601String(),
    'prayerLabel': prayerLabel,
    'locationName': locationName,
  };

  @override
  bool operator ==(Object other) =>
      other is LiveActivityState &&
      other.prayer == prayer &&
      other.prayerTime == prayerTime &&
      other.prayerLabel == prayerLabel &&
      other.locationName == locationName;

  @override
  int get hashCode =>
      Object.hash(prayer, prayerTime, prayerLabel, locationName);
}

/// Etkinliğin kilit ekranında kaç dakika önce belirmesi gerektiği.
///
/// Bütün gün duran bir canlı etkinlik kilit ekranını meşgul eder ve iOS onu
/// zaten sekiz saatle sınırlar. Bir saat, "yaklaşıyor" demek için yeterli.
const liveActivityLeadMinutes = 60;

/// Vakit girdikten sonra etkinliğin ekranda kalacağı süre.
///
/// Vakit girer girmez kaybolmak, ezanı kaçıran kullanıcıya hiçbir şey
/// söylemezdi.
const liveActivityLingerMinutes = 15;

/// Canlı etkinlikle yapılacak iş.
enum LiveActivityAction {
  /// Yeni etkinlik başlat.
  start,

  /// Süren etkinliği güncelle.
  update,

  /// Süren etkinliği bitir.
  end,

  /// Yapılacak bir şey yok.
  none,
}

/// [now] anında etkinlik görünmeli mi?
bool liveActivityIsDue(DateTime now, DateTime prayerTime) {
  final difference = prayerTime.difference(now);
  if (difference > const Duration(minutes: liveActivityLeadMinutes)) {
    return false;
  }
  return difference >= const Duration(minutes: -liveActivityLingerMinutes);
}

/// Süren etkinlikle olması gereken durumu karşılaştırır.
///
/// [running] süren etkinliğin durumu; yoksa null. Karşılaştırma **durum
/// üzerinden** yapılır: aynı vakit için ikinci kez `start` çağırmak iOS'ta
/// ikinci bir etkinlik açar ve kilit ekranında iki sayaç birden görünür.
LiveActivityAction liveActivityAction({
  required DateTime now,
  required LiveActivityState? desired,
  required LiveActivityState? running,
}) {
  final due = desired != null && liveActivityIsDue(now, desired.prayerTime);
  if (!due) {
    return running == null ? LiveActivityAction.none : LiveActivityAction.end;
  }
  if (running == null) return LiveActivityAction.start;
  return running == desired
      ? LiveActivityAction.none
      : LiveActivityAction.update;
}

/// Canlı etkinliği yöneten native köprü.
///
/// Android'de ve test ortamında karşılığı yoktur; çağrılar sessizce atlanır.
class LiveActivityService {
  static const channel = MethodChannel('dini/live_activity');

  const LiveActivityService();

  Future<void> start(LiveActivityState state) async =>
      _invoke('start', state.toJson());

  Future<void> update(LiveActivityState state) async =>
      _invoke('update', state.toJson());

  Future<void> end() async => _invoke('end', null);

  Future<void> _invoke(String method, Map<String, dynamic>? payload) async {
    try {
      await channel.invokeMethod(
        method,
        payload == null ? null : {'state': jsonEncode(payload)},
      );
    } on MissingPluginException {
      // iOS dışında (ve testte) canlı etkinlik yoktur.
    } on PlatformException {
      // Kullanıcı canlı etkinlikleri kapatmış olabilir; uygulama bundan
      // etkilenmemeli.
    }
  }
}
