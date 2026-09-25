import 'dart:convert';
import 'dart:io';

import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/widgets/data/widget_preferences_repository.dart';
import 'package:dini_flutter/features/widgets/data/widget_snapshot_builder.dart';
import 'package:dini_flutter/features/widgets/domain/widget_snapshot.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Native köprüye gidenleri yakalar.
class _RecordingService implements WidgetSnapshotService {
  final calls = <String>[];
  Map<String, dynamic>? payload;
  bool? showLocationName;

  @override
  Future<void> update(
    WidgetSnapshot snapshot, {
    required bool showLocationName,
  }) async {
    calls.add('update');
    this.showLocationName = showLocationName;
    payload = jsonDecode(
      jsonEncode(snapshot.toJson(showLocationName: showLocationName)),
    );
  }

  @override
  Future<void> clearSnapshot() async => calls.add('clear');

  @override
  Future<void> refresh() async => calls.add('refresh');
}

void main() {
  setUpAll(TimezoneService.initialize);

  group('anlık görüntü', () {
    test('widget\'a veri yazılır, yalnızca tazelenmez', () async {
      // Bu yol yazılana kadar uygulama yalnızca "tazele" diyordu; uzantının
      // okuyacağı değerleri kimse yazmıyordu ve widget hep yer tutucu
      // gösteriyordu.
      final storage = _MemoryStorage();
      final service = _RecordingService();

      await pushWidgetSnapshot(
        storage: storage,
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 20, 9),
        service: service,
      );

      expect(service.calls, ['update', 'refresh']);
      expect(service.payload, isNotNull);
      expect(service.payload!['nextPrayerTime'], isNotNull);
    });

    test('vakit adları kullanıcının dilinde gider', () async {
      // Uzantının çeviri haritasına erişimi yok; ad gönderilmezse widget'ta
      // "maghrib" yazar.
      for (final language in ['tr', 'en', 'ar']) {
        final storage = _MemoryStorage();
        await storage.write(localePreferenceKey, language);
        final service = _RecordingService();

        await pushWidgetSnapshot(
          storage: storage,
          settings: const PrayerSettings(),
          now: DateTime.utc(2026, 9, 20, 9),
          service: service,
        );

        final l10n = AppLocalizations(Locale(language));
        expect(
          service.payload!['label_maghrib'],
          l10n.prayer('maghrib'),
          reason: '$language için etiket gönderilmedi.',
        );
        expect(
          service.payload!['nextPrayerLabel'],
          l10n.prayer(service.payload!['nextPrayer'] as String),
        );
      }
    });

    test('sıradaki vakit ve günün vakitleri doludur', () {
      final snapshot = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 20, 9),
        languageCode: 'tr',
      );
      final json = snapshot.toJson(showLocationName: true);

      for (final key in [
        'fajr',
        'sunrise',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      ]) {
        expect(json[key], isNotNull, reason: '$key vakti gönderilmedi.');
      }
      expect(snapshot.nextPrayer, isNotNull);
      expect(snapshot.nextPrayerTime!.isAfter(snapshot.effectiveDate), isTrue);
    });

    test('konum adı ayarı kapalıyken gönderilmez', () async {
      // Ayar kilit ekranında ve ana ekranda şehir adını gizlemek içindir;
      // anlık görüntüde taşındığı için yalnızca tazelemek yetmez.
      final storage = _MemoryStorage();
      final service = _RecordingService();
      await WidgetPreferencesRepository(storage).setShowLocationName(false);

      await pushWidgetSnapshot(
        storage: storage,
        settings: const PrayerSettings(
          location: LocationPreference(
            city: 'İstanbul',
            latitude: 41.0082,
            longitude: 28.9784,
            timezoneId: 'Europe/Istanbul',
          ),
        ),
        now: DateTime.utc(2026, 9, 20, 9),
        service: service,
      );

      expect(service.showLocationName, isFalse);
      expect(service.payload!['locationName'], isNull);
    });

    test('konum adı ayarı açıkken gönderilir', () async {
      final storage = _MemoryStorage();
      final service = _RecordingService();
      await WidgetPreferencesRepository(storage).setShowLocationName(true);

      await pushWidgetSnapshot(
        storage: storage,
        settings: const PrayerSettings(
          location: LocationPreference(
            city: 'Konya',
            latitude: 37.8746,
            longitude: 32.4932,
            timezoneId: 'Europe/Istanbul',
          ),
        ),
        now: DateTime.utc(2026, 9, 20, 9),
        service: service,
      );

      expect(service.payload!['locationName'], 'Konya');
    });

    test('vakitler seçilen şehre göre hesaplanır', () {
      final istanbul = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 20, 9),
        languageCode: 'tr',
      );
      final konya = buildWidgetSnapshot(
        settings: const PrayerSettings(
          location: LocationPreference(
            city: 'Konya',
            latitude: 37.8746,
            longitude: 32.4932,
            timezoneId: 'Europe/Istanbul',
          ),
        ),
        now: DateTime.utc(2026, 9, 20, 9),
        languageCode: 'tr',
      );

      expect(
        istanbul.prayers[Prayer.maghrib],
        isNot(konya.prayers[Prayer.maghrib]),
        reason: 'Şehir değişmesine rağmen vakitler aynı.',
      );
    });
  });

  group('kanal hatası', () {
    testWidgets('native hata uygulamaya sızmaz', (tester) async {
      // Köprü hata dönerse (bozuk anlık görüntü, eski sürüm) ayar kaydı ve
      // açılış durmamalı; widget ikincil bir özellik.
      const channel = MethodChannel('dini/widget_snapshot');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'INVALID_SNAPSHOT'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      const service = WidgetSnapshotService();
      final snapshot = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 21, 3),
        languageCode: 'tr',
      );
      await expectLater(
        service.update(snapshot, showLocationName: false),
        completes,
      );
      await expectLater(service.refresh(), completes);
      await expectLater(service.clearSnapshot(), completes);
    });
  });

  group('native taraf', () {
    late String widget;

    setUpAll(() {
      widget = File('ios/DiniWidget/DiniWidget.swift').readAsStringSync();
    });

    test('uzantı hazır etiketleri okur', () {
      // Okumazsa kullanıcı Türkçe uygulamada "Maghrib" görür.
      expect(widget, contains('nextPrayerLabel'));
      expect(widget, contains('label_'));
    });

    test('uzantı Dart\'ın yazdığı tarih biçimini çözebiliyor', () {
      // Dart tarafı TZDateTime yazıyor: "2026-09-21T05:17:00.000+0300".
      // Salt `ISO8601DateFormatter()` saliseyi kabul etmez ve nil döner;
      // widget o zaman bütün vakitleri "—" gösterir. Telefondaki widget
      // tam olarak böyle görünüyordu.
      final snapshot = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 21, 3),
        languageCode: 'tr',
      ).toJson(showLocationName: true);

      final written = snapshot['fajr'] as String;
      expect(
        written,
        matches(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{4}$'),
        reason: 'Yazılan biçim değişti; native çözümleyici buna göre yazıldı.',
      );
      expect(
        widget,
        contains('withFractionalSeconds'),
        reason:
            'Uzantı saliseli ISO 8601 biçimini çözemiyor; bütün vakitler '
            '"—" görünür.',
      );
    });

    test('ana ekran düzeninde her yazının rengi açıkça veriliyor', () {
      // Widget'ın zemini her görünümde koyu; `.secondary` ve varsayılan yazı
      // rengi ise sistemin görünümünü izler ve aydınlık kipte koyulaşır.
      // Telefondaki widget bu yüzden okunmuyordu.
      final start = widget.indexOf('private var home: some View {');
      expect(start, isNot(-1), reason: 'Ana ekran düzeni bulunamadı.');
      final end = widget.indexOf('\n    }', start);
      final body = widget.substring(start, end);

      for (final line in body.split('\n')) {
        if (!line.contains('Text(')) continue;
        expect(
          line,
          contains('foregroundStyle('),
          reason:
              'Rengi verilmemiş bir yazı var, koyu zeminde kaybolur:\n'
              '${line.trim()}',
        );
        expect(
          line,
          isNot(contains('foregroundStyle(.secondary)')),
          reason:
              '`.secondary` sistemin görünümünü izler; aydınlık kipte '
              'koyu zeminde okunmaz:\n${line.trim()}',
        );
      }
    });

    test('köprü null değeri UserDefaults\'a yazmaz', () {
      // Konum adı ayarı varsayılan olarak kapalı; anlık görüntü her
      // açılışta "locationName": null taşıyor. JSON'daki null Swift'te
      // NSNull olur ve UserDefaults onu kabul etmez: "Attempt to insert
      // non-property list object" istisnası uygulamayı AÇILIŞTA çökertti
      // (TestFlight 1.0.0 (10)).
      final snapshot = buildWidgetSnapshot(
        settings: const PrayerSettings(),
        now: DateTime.utc(2026, 9, 21, 3),
        languageCode: 'tr',
      ).toJson(showLocationName: false);
      expect(
        snapshot.values.any((value) => value == null),
        isTrue,
        reason:
            'Anlık görüntü artık null taşımıyorsa bu test yeniden '
            'düşünülmeli.',
      );

      final bridge = File('ios/Runner/WidgetSnapshotBridge.swift')
          .readAsStringSync();
      expect(
        bridge,
        contains('is NSNull'),
        reason:
            'Köprü NSNull değerini ayıklamıyor; UserDefaults istisna '
            'fırlatır ve uygulama açılışta çöker.',
      );
      expect(bridge, contains('removeObject(forKey:'));
    });

    test('yenileme çağrısı argümansız da kabul edilir', () {
      // Dart `refreshWidgets` ve `clearSnapshot`'ı argümansız çağırıyor;
      // köprü her çağrıda argüman isterse bu ikisi hep hata döner.
      final bridge = File('ios/Runner/WidgetSnapshotBridge.swift')
          .readAsStringSync();
      final guardAt = bridge.indexOf('call.arguments as? [String: Any]');
      final updateAt = bridge.indexOf('case "updateSnapshot"');
      expect(guardAt, isNot(-1));
      expect(
        guardAt,
        greaterThan(updateAt),
        reason: 'Argüman denetimi bütün çağrıların önünde duruyor.',
      );
    });

    test('kilit ekranı boyutları destekleniyor', () {
      for (final family in [
        'accessoryCircular',
        'accessoryRectangular',
        'accessoryInline',
      ]) {
        expect(widget, contains(family), reason: '$family eksik.');
      }
    });
  });
}
