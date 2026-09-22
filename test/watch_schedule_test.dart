import 'dart:io';

import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/watch/data/watch_schedule_builder.dart';
import 'package:dini_flutter/features/watch/domain/watch_schedule.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Değerin herhangi bir derinliğinde null var mı?
bool _hasNull(Object? value) => switch (value) {
  null => true,
  Map() => value.values.any(_hasNull),
  List() => value.any(_hasNull),
  _ => false,
};

void main() {
  setUpAll(TimezoneService.initialize);

  WatchSchedule schedule({
    PrayerSettings settings = const PrayerSettings(),
    DateTime? now,
    String languageCode = 'tr',
    bool showLocationName = false,
  }) => buildWatchSchedule(
    settings: settings,
    now: now ?? DateTime.utc(2026, 9, 21, 9),
    languageCode: languageCode,
    showLocationName: showLocationName,
  );

  group('çizelge', () {
    test('iki haftalık ardışık günler', () {
      final days = schedule().days;
      expect(days, hasLength(watchScheduleDays));
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i].date.difference(days[i - 1].date).inDays,
          1,
          reason: '${days[i - 1].date} ile ${days[i].date} ardışık değil.',
        );
      }
    });

    test('ilk gün seçilen şehrin bugünüdür, cihazın değil', () {
      // 20 Şubat 22:00 UTC, İstanbul'da 21 Şubat 01:00'dir. Cihazın günü
      // alınsaydı saat bir gün geriden başlardı.
      final first = schedule(now: DateTime.utc(2026, 2, 20, 22)).days.first;
      expect(
        [first.date.year, first.date.month, first.date.day],
        [2026, 2, 21],
      );
    });

    test('vakitler uygulamanın kendi motoruyla aynı', () {
      // Saat ile telefon arasında dakika farkı olmamalı.
      final day = schedule().days[3];
      final expected = const LocalPrayerTimesCalculator().calculate(
        day.date,
        const Coordinates(41.0082, 28.9784),
        timezoneId: 'Europe/Istanbul',
      );
      for (final prayer in watchPrayers) {
        expect(day.times[prayer], expected.times[prayer], reason: '$prayer');
      }
    });

    test('yaz saati geçişi bir günü atlatmaz', () {
      // Berlin'de 28 Mart 2027'de saatler ileri alınır; 24 saat eklemek
      // bu gece bir günü atlatabilirdi.
      final settings = const PrayerSettings().copyWith(
        location: const LocationPreference(
          latitude: 52.52,
          longitude: 13.405,
          timezoneId: 'Europe/Berlin',
          city: 'Berlin',
        ),
      );
      // Gece yarısına yarım saat kala (Berlin 23:30 CET): ertesi gece bir
      // saat kısa olduğu için "24 saat ekle" 28'ini atlayıp 29'una düşer.
      // Gün ortasındaki bir saat bu hatayı GÖSTERMEZ; ilk sürüm bu yüzden
      // boşa geçiyordu.
      final days = schedule(
        settings: settings,
        now: DateTime.utc(2027, 3, 27, 22, 30),
      ).days;
      final dates = days.map((day) => day.date.day).toList();
      expect(dates.take(4), [27, 28, 29, 30]);
    });
  });

  group('saate giden veri', () {
    test('hiçbir yerde null yok', () {
      // JSON'daki null Swift'te NSNull olur; property-list olmayan değer
      // uygulamayı çökertti (TestFlight 1.0.0 (10)).
      final payload = schedule(showLocationName: false).toPayload();
      expect(_hasNull(payload), isFalse);
      expect(payload.containsKey('locationName'), isFalse);
    });

    test('konum adı yalnızca izin verilince gider', () {
      final settings = const PrayerSettings().copyWith(
        location: const LocationPreference(
          latitude: 39.93,
          longitude: 32.86,
          timezoneId: 'Europe/Istanbul',
          city: 'Ankara',
        ),
      );
      expect(
        schedule(
          settings: settings,
          showLocationName: true,
        ).toPayload()['locationName'],
        'Ankara',
      );
      expect(
        schedule(
          settings: settings,
          showLocationName: false,
        ).toPayload().containsKey('locationName'),
        isFalse,
      );
    });

    test('anlar Unix saniyesi, tarih metni değil', () {
      // ISO metni Swift'te biçimlendirici seçeneklerine bağlıydı ve widget'ta
      // bütün vakitler "—" görünmüştü.
      final built = schedule();
      final payload = built.toPayload();
      final days = payload['days']! as List;
      final first = days.first as Map;
      expect(first['fajr'], isA<int>());
      expect(
        first['fajr'],
        built.days.first.times[Prayer.fajr]!.millisecondsSinceEpoch ~/ 1000,
      );
      expect(first['date'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    });

    test('saatin arayüz metinleri de gider, üç dilde', () {
      for (final language in ['tr', 'en', 'ar']) {
        final texts =
            schedule(languageCode: language).toPayload()['texts']! as Map;
        for (final key in watchTextKeys) {
          expect(texts[key], isA<String>(), reason: '$language/$key');
          expect(texts[key], isNot(key), reason: '$language/$key çevrilmemiş');
        }
      }
    });

    test('saat vakitleri seçilen şehrin diliminde yazar', () {
      // Yolculukta saatin kendi dilimi şehirden farklı olabilir; telefon
      // vakitleri şehrin duvar saatinde gösteriyor, saat de öyle yapmalı.
      final settings = const PrayerSettings().copyWith(
        location: const LocationPreference(
          latitude: 52.52,
          longitude: 13.405,
          timezoneId: 'Europe/Berlin',
          city: 'Berlin',
        ),
      );
      expect(
        schedule(settings: settings).toPayload()['timezoneId'],
        'Europe/Berlin',
      );
    });

    test('vakit adları kullanıcının dilinde', () {
      final tr = schedule(languageCode: 'tr').toPayload()['labels']! as Map;
      final ar = schedule(languageCode: 'ar').toPayload()['labels']! as Map;
      expect(tr['maghrib'], 'Akşam');
      expect(ar['maghrib'], isNot('Akşam'));
      expect(ar['maghrib'], isNot('maghrib'));
    });
  });

  group('kanal', () {
    testWidgets('native hata uygulamaya sızmaz', (tester) async {
      // Saat eşleşmemişse köprü hata dönebilir; ayar kaydı durmamalı.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WatchScheduleService.channel,
        (call) async => throw PlatformException(code: 'NOT_PAIRED'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          WatchScheduleService.channel,
          null,
        ),
      );
      await expectLater(
        const WatchScheduleService().send(schedule()),
        completes,
      );
    });
  });

  group('native taraf', () {
    test('köprü uygulamaya kaydedilmiş ve kanal adı aynı', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('WatchBridge.register'));
      final bridge = File('ios/Runner/WatchBridge.swift').readAsStringSync();
      expect(bridge, contains('"${WatchScheduleService.channel.name}"'));
    });

    test('oturum etkinleşmeden gelen çizelge kaybolmaz', () {
      // WCSession eşzamansız etkinleşir; ilk açılışta çizelge etkinleşmeden
      // gelir. Bekletilmezse saat bir sonraki açılışa kadar boş kalır.
      final bridge = File('ios/Runner/WatchBridge.swift').readAsStringSync();
      expect(bridge, contains('pending = schedule'));
      expect(bridge, contains('activationDidCompleteWith'));
    });
  });

  group('saat uygulaması', () {
    test('Dart\'ın gönderdiği her anahtarı okur', () {
      // Bir anahtarın adı iki tarafta ayrılırsa hiçbir hata olmaz; saat o
      // alanı sessizce boş gösterir.
      final reader = File('ios/DiniWatch/WatchSchedule.swift')
          .readAsStringSync();
      final payload = schedule(showLocationName: true).toPayload();
      for (final key in [
        'generatedAt',
        'timezoneId',
        'labels',
        'texts',
        'days',
        'locationName',
      ]) {
        expect(reader, contains('"$key"'), reason: 'saat "$key" okumuyor');
      }
      expect(payload.keys, containsAll(['generatedAt', 'timezoneId', 'days']));
      for (final prayer in watchPrayers) {
        expect(reader, contains('"${prayer.name}"'));
      }
      for (final key in watchTextKeys) {
        expect(reader, contains('"$key"'), reason: 'yedek metin eksik: $key');
      }
    });

    test('geri sayım ters aralık kurmaz', () {
      // Kilit ekranı sayacında "Date()...vakit" aralığı vakit geçince
      // ters dönüyordu; saat aynı hatayı tekrarlamamalı.
      final view = File('ios/DiniWatch/ContentView.swift').readAsStringSync();
      expect(view, isNot(contains('now...next.time')));
      expect(view, contains('min(now, next.time)...next.time'));
    });

    test('vakitleri şehrin diliminde yazar', () {
      final view = File('ios/DiniWatch/ContentView.swift').readAsStringSync();
      expect(
        view,
        isNot(contains('style: .time')),
        reason: 'Text(date, style: .time) saatin kendi dilimini kullanır.',
      );
    });
  });

  group('bağlantı', () {
    // Widget'la aynı üç anda gönderilmezse saat eski şehrin vakitlerini
    // göstermeye devam eder.
    for (final path in [
      'lib/main.dart',
      'lib/features/prayer_times/presentation/save_settings.dart',
      'lib/app/router.dart',
    ]) {
      test('$path saate de gönderir', () {
        expect(File(path).readAsStringSync(), contains('pushWatchSchedule('));
      });
    }
  });
}
