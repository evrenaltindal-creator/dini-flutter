import 'dart:convert';
import 'dart:io';

import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/widgets/data/live_activity_controller.dart';
import 'package:dini_flutter/features/widgets/domain/live_activity.dart';
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

/// Native köprüye giden çağrıları sayar.
class _RecordingService implements LiveActivityService {
  final calls = <String>[];
  LiveActivityState? last;

  @override
  Future<void> start(LiveActivityState state) async {
    calls.add('start');
    last = state;
  }

  @override
  Future<void> update(LiveActivityState state) async {
    calls.add('update');
    last = state;
  }

  @override
  Future<void> end() async => calls.add('end');
}

final maghrib = DateTime(2026, 9, 20, 19, 0);

LiveActivityState state({DateTime? time, String label = 'Akşam'}) =>
    LiveActivityState(
      prayer: Prayer.maghrib,
      prayerTime: time ?? maghrib,
      prayerLabel: label,
      locationName: 'İstanbul',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TimezoneService.initialize);

  group('ne zaman görünür', () {
    test('bir saatten uzaksa görünmez', () {
      // Bütün gün duran bir canlı etkinlik kilit ekranını meşgul eder.
      expect(
        liveActivityIsDue(maghrib.subtract(const Duration(hours: 2)), maghrib),
        isFalse,
      );
      expect(
        liveActivityIsDue(
          maghrib.subtract(const Duration(minutes: 61)),
          maghrib,
        ),
        isFalse,
      );
    });

    test('bir saat kala görünür', () {
      expect(
        liveActivityIsDue(
          maghrib.subtract(const Duration(minutes: 60)),
          maghrib,
        ),
        isTrue,
      );
      expect(
        liveActivityIsDue(
          maghrib.subtract(const Duration(minutes: 1)),
          maghrib,
        ),
        isTrue,
      );
    });

    test('vakit girdikten sonra bir süre kalır', () {
      // Vakit girer girmez kaybolmak, ezanı kaçırana hiçbir şey söylemezdi.
      expect(
        liveActivityIsDue(maghrib.add(const Duration(minutes: 14)), maghrib),
        isTrue,
      );
      expect(
        liveActivityIsDue(maghrib.add(const Duration(minutes: 16)), maghrib),
        isFalse,
      );
    });
  });

  group('hangi iş yapılır', () {
    final now = maghrib.subtract(const Duration(minutes: 30));

    test('sırası gelmemişse ve etkinlik yoksa iş yok', () {
      expect(
        liveActivityAction(
          now: maghrib.subtract(const Duration(hours: 3)),
          desired: state(),
          running: null,
        ),
        LiveActivityAction.none,
      );
    });

    test('sırası geçmişse süren etkinlik bitirilir', () {
      expect(
        liveActivityAction(
          now: maghrib.add(const Duration(hours: 1)),
          desired: state(),
          running: state(),
        ),
        LiveActivityAction.end,
      );
    });

    test('sırası gelmişse ve etkinlik yoksa başlatılır', () {
      expect(
        liveActivityAction(now: now, desired: state(), running: null),
        LiveActivityAction.start,
      );
    });

    test('aynı durum için ikinci kez başlatılmaz', () {
      // İkinci `start` kilit ekranında ikinci bir sayaç açardı.
      expect(
        liveActivityAction(now: now, desired: state(), running: state()),
        LiveActivityAction.none,
      );
    });

    test('durum değişmişse güncellenir', () {
      expect(
        liveActivityAction(
          now: now,
          desired: state(label: 'Maghrib'),
          running: state(),
        ),
        LiveActivityAction.update,
      );
    });

    test('sıradaki vakit yoksa etkinlik bitirilir', () {
      expect(
        liveActivityAction(now: now, desired: null, running: state()),
        LiveActivityAction.end,
      );
    });
  });

  group('denetleyici', () {
    test('başlatılan durum aynaya yazılır', () async {
      final storage = _MemoryStorage();
      final service = _RecordingService();
      final controller = LiveActivityController(
        storage: storage,
        service: service,
      );
      final now = maghrib.subtract(const Duration(minutes: 20));

      expect(
        await controller.sync(now: now, desired: state()),
        LiveActivityAction.start,
      );
      expect(service.calls, ['start']);
      expect(
        storage.values.containsKey(LiveActivityController.stateKey),
        isTrue,
      );

      // Ayna olmasaydı ikinci açılışta ikinci bir etkinlik başlatılırdı.
      expect(
        await controller.sync(now: now, desired: state()),
        LiveActivityAction.none,
      );
      expect(service.calls, ['start']);
    });

    test('bitirilen etkinliğin aynası silinir', () async {
      final storage = _MemoryStorage();
      final service = _RecordingService();
      final controller = LiveActivityController(
        storage: storage,
        service: service,
      );
      await controller.sync(
        now: maghrib.subtract(const Duration(minutes: 5)),
        desired: state(),
      );
      await controller.sync(
        now: maghrib.add(const Duration(hours: 2)),
        desired: state(),
      );

      expect(service.calls, ['start', 'end']);
      expect(
        storage.values.containsKey(LiveActivityController.stateKey),
        isFalse,
      );
    });

    test('bozuk ayna etkinliği engellemez', () async {
      final storage = _MemoryStorage();
      storage.values[LiveActivityController.stateKey] = '{bozuk';
      final service = _RecordingService();

      expect(
        await LiveActivityController(storage: storage, service: service).sync(
          now: maghrib.subtract(const Duration(minutes: 5)),
          desired: state(),
        ),
        LiveActivityAction.start,
      );
    });
  });

  group('metin ve içerik', () {
    test('vakit adı kullanıcının dilinde gönderilir', () async {
      // Uzantının çeviri haritasına erişimi yok; çeviri burada yapılmazsa
      // kilit ekranı uygulamanın dilinden bağımsız görünürdü.
      // "Şimdi", akşam vaktinin on dakika öncesine kurulur: sabit bir saat
      // seçmek vakitlerin gününe göre pencerenin dışında kalabilirdi.
      const settings = PrayerSettings();
      final times = const LocalPrayerTimesCalculator().calculate(
        TimezoneService.inLocation(
          'Europe/Istanbul',
          DateTime.utc(2026, 9, 20, 9),
        ),
        const Coordinates(41.0082, 28.9784),
        method: settings.method,
        asrMethod: settings.asrMethod,
        timezoneId: 'Europe/Istanbul',
      );
      final now = times.times[Prayer.maghrib]!.subtract(
        const Duration(minutes: 10),
      );

      for (final language in ['tr', 'en', 'ar']) {
        final storage = _MemoryStorage();
        await storage.write(localePreferenceKey, language);
        final service = _RecordingService();

        await syncLiveActivity(
          storage: storage,
          settings: settings,
          now: now,
          service: service,
        );

        final label = service.last?.prayerLabel;
        expect(label, isNotNull, reason: '$language için etkinlik kurulmadı.');
        expect(
          label,
          AppLocalizations(Locale(language)).prayer(service.last!.prayer.name),
        );
      }
    });

    test('json ile gidip gelen durum aynı kalır', () {
      final encoded = jsonEncode(state().toJson());
      final map = jsonDecode(encoded) as Map<String, dynamic>;
      expect(map['prayer'], 'maghrib');
      expect(map['prayerLabel'], 'Akşam');
      expect(DateTime.parse(map['prayerTime'] as String), maghrib);
      expect(map['locationName'], 'İstanbul');
    });

    test('native köprü yokken çağrı sessizce geçilir', () async {
      // Android'de ve testte kanal yoktur; uygulama bundan etkilenmemeli.
      await expectLater(const LiveActivityService().start(state()), completes);
      await expectLater(const LiveActivityService().end(), completes);
    });

    test('platform hatası yutulur', () async {
      // Kullanıcı kilit ekranı etkinliklerini kapatmış olabilir.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            LiveActivityService.channel,
            (call) async => throw PlatformException(code: 'DISABLED'),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(LiveActivityService.channel, null),
      );

      await expectLater(const LiveActivityService().start(state()), completes);
    });
  });

  group('native taraf', () {
    test('canlı etkinlik desteği Info.plist\'te bildirilmiş', () {
      // Bildirilmezse iOS isteği reddeder ve kilit ekranında hiçbir şey
      // görünmez.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSSupportsLiveActivities'));
    });

    test('köprü uygulamaya kaydedilmiş', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('LiveActivityBridge.register'));
    });

    test('etkinlik widget paketine eklenmiş', () {
      final bundle = File('ios/DiniWidget/DiniWidget.swift').readAsStringSync();
      expect(bundle, contains('PrayerLiveActivity()'));
    });

    test('köprü Dart\'ın yazdığı tarih biçimini çözebiliyor', () {
      // Dart "2026-09-21T05:17:00.000+0300" gönderiyor; salt
      // `ISO8601DateFormatter()` saliseyi kabul etmediği için çözümleme
      // nil dönüyor, köprü INVALID_STATE veriyor ve kilit ekranında hiçbir
      // şey açılmıyordu.
      final bridge = File('ios/Runner/LiveActivityBridge.swift')
          .readAsStringSync();
      expect(
        bridge,
        contains('withFractionalSeconds'),
        reason: 'Köprü saliseli ISO 8601 biçimini çözemiyor.',
      );
    });

    test('geri sayım vakit geçince ters aralık kurmaz', () {
      // Etkinlik vakitten sonra `liveActivityLingerMinutes` boyunca
      // ekranda kalıyor. "Date()...vakit" o sırada ters bir aralık olur ve
      // Swift ters ClosedRange kurulunca uzantıyı çökertir.
      expect(liveActivityLingerMinutes, greaterThan(0));
      final view = File('ios/DiniWidget/PrayerLiveActivity.swift')
          .readAsStringSync();
      expect(
        view,
        isNot(contains('Date()...')),
        reason:
            'Geri sayım aralığı şimdiki andan başlıyor; vakit geçince '
            'ters döner ve uzantı çöker.',
      );
      expect(view, contains('min(now, prayerTime)...prayerTime'));
    });

    test('kanal adı iki tarafta aynı', () {
      // Ad ayrılırsa çağrılar sessizce boşa gider.
      final bridge = File('ios/Runner/LiveActivityBridge.swift')
          .readAsStringSync();
      expect(bridge, contains('"dini/live_activity"'));
      expect(LiveActivityService.channel.name, 'dini/live_activity');
    });
  });
}
