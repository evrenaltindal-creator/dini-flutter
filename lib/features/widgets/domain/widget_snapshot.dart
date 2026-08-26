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
  const WidgetSnapshot({
    required this.effectiveDate,
    required this.locationName,
    required this.prayers,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.scenePeriod,
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
    'nextPrayerTime': nextPrayerTime?.toIso8601String(),
    'scenePeriod': scenePeriod.name,
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
    }
  }

  Future<void> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearSnapshot');
    } on MissingPluginException {
      // Native widgets are unavailable in the Linux/test host.
    }
  }

  Future<void> refresh() async {
    try {
      await _channel.invokeMethod('refreshWidgets');
    } on MissingPluginException {
      // Native widgets are unavailable in the Linux/test host.
    }
  }
}
