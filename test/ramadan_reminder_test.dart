import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/features/calendar/domain/islamic_calendar.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/widgets.dart';
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

NotificationTextResolver _in(String languageCode) =>
    (key, [values = const {}]) =>
        AppLocalizations(Locale(languageCode)).text(key, values);

const _istanbul = Coordinates(41.0082, 28.9784);
const _calculator = LocalPrayerTimesCalculator();

/// Ramazan'a düşen bir gün bulur. Hicri takvim tabular olduğu için tarihi
/// elle sabitlemek yerine aranır; takvim tablosu güncellenirse test kırılmaz.
DateTime _aDayInRamadan() {
  const calendar = IslamicCalendar();
  var date = DateTime(2026);
  for (var step = 0; step < 1500; step++) {
    if (calendar.hijri(date).month == 9) return date;
    date = date.add(const Duration(days: 1));
  }
  fail('2026-2029 arasında Ramazan günü bulunamadı.');
}

PrayerTimes _timesOn(DateTime date) =>
    _calculator.calculate(date, _istanbul, timezoneId: 'Europe/Istanbul');

void main() {
  setUpAll(TimezoneService.initialize);

  final ramadanDay = _aDayInRamadan();

  List<PlannedNotification> planFor(
    NotificationPreferences preferences, {
    String language = 'tr',
    DateTime? date,
  }) => const NotificationSchedulePlanner().plan(
    days: [_timesOn(date ?? ramadanDay)],
    preferences: preferences,
    text: _in(language),
  );

  group('bildirim metni kullanıcının dilinde', () {
    // Başlık ve gövdeler doğrudan Türkçe yazılıydı: İngilizce ya da Arapça
    // kullanan biri "Sahur yaklaşıyor" bildirimini Türkçe alıyordu.
    const preferences = NotificationPreferences(
      prayers: {Prayer.fajr: PrayerNotificationPreference(enabled: true)},
      ramadanSuhoorReminder: true,
      ramadanIftarReminder: true,
    );

    test('İngilizce planda Türkçe metin kalmaz', () {
      final planned = planFor(preferences, language: 'en');
      expect(planned, isNotEmpty);
      for (final item in planned) {
        expect(
          '${item.title} ${item.body}',
          isNot(anyOf(contains('vakti'), contains('kaldı'), contains('Sahur'))),
          reason: 'İngilizce bildirimde Türkçe metin var: ${item.title}',
        );
      }
    });

    test('her dil kendi metnini üretir', () {
      String suhoorTitle(String language) => planFor(
        preferences,
        language: language,
      ).firstWhere((i) => i.kind == NotificationKind.ramadanSuhoor).title;

      final titles = {
        for (final language in ['tr', 'en', 'ar'])
          language: suhoorTitle(language),
      };
      expect(
        titles.values.toSet(),
        hasLength(3),
        reason: 'Üç dil aynı başlığı veriyor: $titles',
      );
      for (final title in titles.values) {
        expect(title.trim(), isNotEmpty);
        expect(
          title,
          isNot(startsWith('notify.')),
          reason: 'Anahtar çözülmemiş, ekrana anahtar adı düşüyor: $title',
        );
      }
    });

    test('dakika değeri metne yerleşir', () {
      final planned = planFor(
        const NotificationPreferences(
          ramadanIftarReminder: true,
          iftarMinutes: 45,
        ),
      );
      final soon = planned.firstWhere(
        (i) => i.kind == NotificationKind.ramadanIftarSoon,
      );
      expect(soon.body, contains('45'));
      expect(
        soon.body,
        isNot(contains('{minutes}')),
        reason: 'Yer tutucu değiştirilmemiş.',
      );
    });
  });

  group('sahur ve iftar süreleri', () {
    test('sahur uyarısı seçilen dakika kadar önce planlanır', () {
      // Süre sabit otuz dakikaydı; kalkıp yemek için dar bir süre.
      final times = _timesOn(ramadanDay);
      final fajr = times.times[Prayer.fajr]!;

      for (final minutes in NotificationPreferences.suhoorChoices) {
        final planned = planFor(
          NotificationPreferences(
            ramadanSuhoorReminder: true,
            suhoorMinutes: minutes,
          ),
        );
        final suhoor = planned.firstWhere(
          (i) => i.kind == NotificationKind.ramadanSuhoor,
        );
        expect(
          fajr.difference(suhoor.scheduledAt).inMinutes,
          minutes,
          reason: '$minutes dakikalık sahur uyarısı yanlış saatte.',
        );
      }
    });

    test('iftar hem önceden hem vaktinde uyarır', () {
      // Yalnızca iftar vaktinde bildirim vardı; hazırlık için uyarı yoktu.
      final maghrib = _timesOn(ramadanDay).times[Prayer.maghrib]!;
      final planned = planFor(
        const NotificationPreferences(
          ramadanIftarReminder: true,
          iftarMinutes: 30,
        ),
      );

      final soon = planned.firstWhere(
        (i) => i.kind == NotificationKind.ramadanIftarSoon,
      );
      final atTime = planned.firstWhere(
        (i) => i.kind == NotificationKind.ramadanIftar,
      );
      expect(maghrib.difference(soon.scheduledAt).inMinutes, 30);
      expect(atTime.scheduledAt, maghrib);
    });

    test('sıfır dakika seçilirse yalnızca vaktinde uyarılır', () {
      final planned = planFor(
        const NotificationPreferences(
          ramadanIftarReminder: true,
          iftarMinutes: 0,
        ),
      );
      expect(
        planned.where((i) => i.kind == NotificationKind.ramadanIftarSoon),
        isEmpty,
      );
      expect(
        planned.where((i) => i.kind == NotificationKind.ramadanIftar),
        hasLength(1),
      );
    });

    test('Ramazan dışındaki günde sahur ve iftar planlanmaz', () {
      const calendar = IslamicCalendar();
      var outside = ramadanDay;
      while (calendar.hijri(outside).month == 9) {
        outside = outside.add(const Duration(days: 1));
      }

      final planned = planFor(
        const NotificationPreferences(
          ramadanSuhoorReminder: true,
          ramadanIftarReminder: true,
        ),
        date: outside,
      );
      expect(
        planned,
        isEmpty,
        reason: 'Ramazan dışında sahur/iftar bildirimi gönderilmemeli.',
      );
    });
  });

  group('bildirim kimlikleri', () {
    test('aynı gün içindeki bütün türler ayrı kimlik alır', () {
      // Eski şema gün * 20 + 15 + tür idi; altıncı tür eklendiğinde
      // 15 + 5 = 20 ertesi günün ilk kimliğine denk geliyordu.
      final at = DateTime(2027, 3, 14, 5);
      final ids = <int>{};
      for (final kind in NotificationKind.values) {
        ids.add(notificationId(at, kind));
        for (final prayer in Prayer.values) {
          ids.add(notificationId(at, kind, prayer: prayer));
        }
      }
      expect(
        ids,
        hasLength(NotificationKind.values.length * (Prayer.values.length + 1)),
        reason: 'İki bildirim aynı kimliği paylaşıyor.',
      );
    });

    test('ardışık günler çakışmaz', () {
      final ids = <int>{};
      var count = 0;
      for (var day = 1; day <= 31; day++) {
        final at = DateTime(2027, 3, day);
        for (final kind in NotificationKind.values) {
          ids.add(notificationId(at, kind));
          count++;
        }
      }
      expect(ids, hasLength(count));
    });

    test('kimlik 32 bit tam sayıya sığar', () {
      // Android bildirim kimliği int32'dir; taşarsa planlama sessizce düşer.
      final id = notificationId(
        DateTime(2099, 12, 31),
        NotificationKind.values.last,
        prayer: Prayer.values.last,
      );
      expect(id, lessThan(2147483647));
      expect(id, greaterThan(0));
    });

    test('aynı bildirim iki kez planlanırsa tek kayıt kalır', () {
      final times = _timesOn(ramadanDay);
      final planned = const NotificationSchedulePlanner().plan(
        days: [times, times],
        preferences: const NotificationPreferences(
          ramadanSuhoorReminder: true,
          ramadanIftarReminder: true,
        ),
        text: _in('tr'),
      );
      expect(planned.map((i) => i.id).toSet(), hasLength(planned.length));
    });
  });

  group('süre tercihleri kalıcı', () {
    test('kaydedilen dakikalar geri okunur', () async {
      final storage = _MemoryStorage();
      final repository = NotificationPreferencesRepository(storage);
      await repository.save(
        const NotificationPreferences(suhoorMinutes: 90, iftarMinutes: 15),
      );

      final loaded = await repository.load();
      expect(loaded.suhoorMinutes, 90);
      expect(loaded.iftarMinutes, 15);
    });

    test('hiç kaydedilmemişse makul varsayılanlar gelir', () async {
      final loaded = await NotificationPreferencesRepository(_MemoryStorage())
          .load();
      expect(loaded.suhoorMinutes, 45);
      expect(loaded.iftarMinutes, 30);
    });

    test('bozuk kayıt varsayılana düşer, uyarıyı susturmaz', () async {
      final storage = _MemoryStorage();
      storage.values['dini.notifications.ramadan.suhoor.minutes'] = 'abc';
      final loaded = await NotificationPreferencesRepository(storage).load();
      expect(loaded.suhoorMinutes, 45);
    });
  });

  group('hicri düzeltme bildirimlere ulaşır', () {
    // Kullanıcı resmî ilana uyması için takvimi bir gün kaydırdığında
    // sahur ve iftar bildirimleri de o günlere kaymalıdır. Aksi halde ekran
    // "Ramazan 1" derken bildirim hiç gelmez.
    const preferences = NotificationPreferences(
      ramadanSuhoorReminder: true,
      ramadanIftarReminder: true,
    );

    test('kaydırma Ramazan gününü bildirime taşır', () {
      final dayBefore = ramadanDay.subtract(const Duration(days: 1));
      // Ramazan'ın ilk gününü bul: bir önceki gün Ramazan dışında olmalı.
      const plain = IslamicCalendar();
      if (plain.hijri(dayBefore).month == 9) return;

      final without = const NotificationSchedulePlanner().plan(
        days: [_timesOn(dayBefore)],
        preferences: preferences,
        text: _in('tr'),
      );
      expect(
        without,
        isEmpty,
        reason: 'Düzeltmesiz takvimde bu gün Ramazan değil.',
      );

      final shifted = const NotificationSchedulePlanner().plan(
        days: [_timesOn(dayBefore)],
        preferences: preferences,
        calendar: const IslamicCalendar(dayOffset: 1),
        text: _in('tr'),
      );
      expect(
        shifted,
        isNotEmpty,
        reason:
            'Kaydırma planlayıcıya ulaşmıyor; ekran Ramazan derken bildirim '
            'kurulmuyor.',
      );
    });

    test('koordinatör ayardaki kaydırmayı planlayıcıya geçirir', () async {
      final dayBefore = ramadanDay.subtract(const Duration(days: 1));
      const plain = IslamicCalendar();
      if (plain.hijri(dayBefore).month == 9) return;

      Future<int> scheduledCount(int offset) async {
        final service = _CountingService();
        await PrayerNotificationCoordinator(
          service: service,
          calculator: _calculator,
        ).reschedule(
          // Gün başı: o günün bütün vakitleri kesme noktasından sonradır.
          start: TimezoneService.local(
            'Europe/Istanbul',
            dayBefore.year,
            dayBefore.month,
            dayBefore.day,
          ),
          coordinates: _istanbul,
          settings: PrayerSettings(hijriOffset: offset),
          preferences: preferences,
          text: _in('tr'),
          daysAhead: 0,
        );
        return service.count;
      }

      expect(await scheduledCount(0), 0);
      expect(
        await scheduledCount(1),
        greaterThan(0),
        reason: 'Ayardaki kaydırma koordinatörden planlayıcıya geçmiyor.',
      );
    });
  });
}

/// Kaç bildirim kurulduğunu sayar.
class _CountingService implements LocalNotificationService {
  int count = 0;
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async => count++;
}
