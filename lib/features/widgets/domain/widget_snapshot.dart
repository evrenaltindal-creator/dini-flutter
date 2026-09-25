import 'dart:convert';

import 'package:flutter/services.dart';

import '../../home/domain/mosque_scene_state.dart';
import '../../../shared/models/domain.dart';

class WidgetSnapshot {
  final DateTime effectiveDate;
  final String? locationName;
  final Map<Prayer, DateTime> prayers;
  final Prayer? nextPrayer;
  final DateTime? nextPrayerTime;
  final MosqueScenePeriod scenePeriod;

  /// Vakit adlarının kullanıcının dilindeki karşılığı.
  ///
  /// Uzantının uygulamanın çeviri haritasına erişimi yok; adlar hazır metin
  /// olarak gönderilmezse widget'ta enum adları ("maghrib") görünür.
  final Map<Prayer, String> labels;

  /// Ertesi günün sabah vakti. Uzantı sıradaki vakti her an kendisi seçer;
  /// yatsıdan sonra sıradaki vakit yarının sabahıdır ve uygulama o sırada
  /// açılmamış olabilir.
  final DateTime? tomorrowFajr;

  /// Widget'taki diğer yazılar kullanıcının dilinde: "kaldı" ve kısayol
  /// düğmeleri (Tesbih, Kıble, Takip). Anahtarlar `label_` önekiyle gider.
  final Map<String, String> extraLabels;

  const WidgetSnapshot({
    required this.effectiveDate,
    required this.locationName,
    required this.prayers,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.scenePeriod,
    this.labels = const {},
    this.tomorrowFajr,
    this.extraLabels = const {},
  });
  Map<String, dynamic> toJson({required bool showLocationName}) => {
    'effectiveDate': effectiveDate.toIso8601String(),
    'locationName': showLocationName ? locationName : null,
    'fajr': prayers[Prayer.fajr]?.toIso8601String(),
    'sunrise': prayers[Prayer.sunrise]?.toIso8601String(),
    'dhuhr': prayers[Prayer.dhuhr]?.toIso8601String(),
    'asr': prayers[Prayer.asr]?.toIso8601String(),
    'maghrib': prayers[Prayer.maghrib]?.toIso8601String(),
    'isha': prayers[Prayer.isha]?.toIso8601String(),
    'nextPrayer': nextPrayer?.name,
    'nextPrayerLabel': nextPrayer == null ? null : labels[nextPrayer],
    'nextPrayerTime': nextPrayerTime?.toIso8601String(),
    'scenePeriod': scenePeriod.name,
    'tomorrowFajr': tomorrowFajr?.toIso8601String(),
    for (final entry in labels.entries) 'label_${entry.key.name}': entry.value,
    for (final entry in extraLabels.entries) 'label_${entry.key}': entry.value,
  };
}

class WidgetSnapshotService {
  static const _channel = MethodChannel('dini/widget_snapshot');
  const WidgetSnapshotService();
  Future<void> update(
    WidgetSnapshot snapshot, {
    required bool showLocationName,
  }) async {
    try {
      await _channel.invokeMethod('updateSnapshot', {
        'snapshot': jsonEncode(
          snapshot.toJson(showLocationName: showLocationName),
        ),
        'showLocationName': showLocationName,
      });
    } on MissingPluginException {
      // Native widgets are unavailable in the Linux/test host.
    } on PlatformException {
      // Widget ikincil bir özellik: native tarafın hatası ayar kaydını ya da
      // açılışı durdurmamalı.
    }
  }

  Future<void> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearSnapshot');
    } on MissingPluginException {
      // Native widgets are unavailable in the Linux/test host.
    } on PlatformException {
      // Widget ikincil bir özellik: native tarafın hatası ayar kaydını ya da
      // açılışı durdurmamalı.
    }
  }

  Future<void> refresh() async {
    try {
      await _channel.invokeMethod('refreshWidgets');
    } on MissingPluginException {
      // Native widgets are unavailable in the Linux/test host.
    } on PlatformException {
      // Widget ikincil bir özellik: native tarafın hatası ayar kaydını ya da
      // açılışı durdurmamalı.
    }
  }
}
