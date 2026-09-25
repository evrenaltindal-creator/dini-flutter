@Tags(['store'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/watch/data/watch_schedule_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apple Watch mağaza görselleri için saat çizelgesi.
///
/// Simülatörde eşleşmiş telefon yoktur; saat uygulaması çizelgeyi
/// açılış argümanından alır (`-dini.watch.schedule <...>`, UserDefaults'un
/// argüman alanı). Çizelge uygulamanın kendi motoruyla, o anki saate göre
/// İstanbul için hesaplanır: görseldeki vakitler gerçektir.
/// `.github/workflows/app-store-listing.yml` çalıştırır; CI'da atlanır.
void main() {
  setUpAll(TimezoneService.initialize);

  for (final language in ['tr', 'en']) {
    test('çizelge: $language', () {
      final schedule = buildWatchSchedule(
        settings: const PrayerSettings(),
        now: DateTime.now().toUtc(),
        languageCode: language,
        showLocationName: true,
        days: 2,
      );
      final bytes = utf8.encode(jsonEncode(schedule.toPayload()));
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final out = File('build/watch_store_payload/$language.txt');
      out.parent.createSync(recursive: true);
      // Eski biçim property-list veri değeri: <hex>.
      out.writeAsStringSync('<$hex>');
    });
  }
}
