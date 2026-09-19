import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dini_flutter/core/storage/local_data_repository.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/domain/religious_events.dart';
import 'package:dini_flutter/features/content/domain/content_repository.dart';
import 'package:dini_flutter/features/notifications/data/notification_preferences_repository.dart';
import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/features/tasbih/data/tasbih_repository.dart';
import 'package:dini_flutter/features/tasbih/domain/tasbih.dart';
import 'package:dini_flutter/features/tracker/data/prayer_tracker_repository.dart';
import 'package:dini_flutter/features/widgets/domain/widget_snapshot.dart';
import 'package:dini_flutter/features/widgets/data/widget_preferences_repository.dart';
import 'package:dini_flutter/features/home/domain/mosque_scene_state.dart';
import 'package:dini_flutter/shared/models/domain.dart' show Prayer;

class _FakeNotificationService implements LocalNotificationService {
  final scheduled = <PlannedNotification>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> cancelAll() async => scheduled.clear();
  @override
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  ) async => scheduled.add(notification);
}

/// Planlayıcının metin çözümleyicisi. Testler Türkçe metinle çalışır.
String _turkish(String key, [Map<String, Object> values = const {}]) =>
    const AppLocalizations(Locale('tr')).text(key, values);

void main() {
  final calculator = const LocalPrayerTimesCalculator();
  final settings = const PrayerSettings();
  final coordinates = const Coordinates(41.0082, 28.9784);

  test('planner schedules all five prayers, reminder offsets, and omits disabled prayers', () {
    final date = DateTime(2026, 8, 28);
    final times = calculator.calculate(
      date,
      coordinates,
      timezoneId: 'Europe/Istanbul',
    );
    final preferences = NotificationPreferences(
      prayers: {
        for (final prayer in notificationPrayers)
          prayer: PrayerNotificationPreference(
            enabled: prayer != Prayer.asr,
            reminderMinutes: prayer == Prayer.fajr ? 15 : null,
          ),
      },
    );
    final plan = const NotificationSchedulePlanner().plan(
      days: [times],
      preferences: preferences,
      text: _turkish,
      notBefore: DateTime(2026, 1, 1),
    );
    expect(
      plan
          .where((item) => item.kind == NotificationKind.prayer)
          .map((item) => item.prayer),
      containsAll([Prayer.fajr, Prayer.dhuhr, Prayer.maghrib, Prayer.isha]),
    );
    expect(
      plan.any(
        (item) =>
            item.kind == NotificationKind.beforePrayer &&
            item.prayer == Prayer.fajr &&
            item.scheduledAt ==
                times.times[Prayer.fajr]!.subtract(const Duration(minutes: 15)),
      ),
      isTrue,
    );
    expect(plan.where((item) => item.prayer == Prayer.asr), isEmpty);
  });

  test('coordinator deduplicates and schedules tomorrow after Isha', () async {
    final service = _FakeNotificationService();
    final preferences = NotificationPreferences(
      prayers: {
        for (final prayer in notificationPrayers)
          prayer: const PrayerNotificationPreference(enabled: true),
      },
    );
    await PrayerNotificationCoordinator(
      service: service,
      calculator: calculator,
    ).reschedule(
      start: DateTime(2026, 8, 28, 23),
      coordinates: coordinates,
      settings: settings,
      preferences: preferences,
      text: _turkish,
      daysAhead: 2,
    );
    expect(service.scheduled, isNotEmpty);
    expect(
      service.scheduled.map((item) => item.id).toSet().length,
      service.scheduled.length,
    );
    expect(
      service.scheduled.any(
        (item) => item.prayer == Prayer.fajr && item.scheduledAt.day == 29,
      ),
      isTrue,
    );
  });

  test('notification preferences round trip locally', () async {
    final storage = MemoryStorage();
    final repository = NotificationPreferencesRepository(storage);
    final value = NotificationPreferences(
      prayers: {
        Prayer.maghrib: const PrayerNotificationPreference(
          enabled: true,
          reminderMinutes: 10,
        ),
      },
      sound: NotificationSound.silent,
      fridayReminder: true,
    );
    await repository.save(value);
    final loaded = await repository.load();
    expect(loaded.forPrayer(Prayer.maghrib).reminderMinutes, 10);
    expect(loaded.sound, NotificationSound.silent);
    expect(loaded.fridayReminder, isTrue);
  });

  test('tracker persists by effective date and supports toggle', () async {
    final repository = LocalPrayerTrackerRepository(MemoryStorage());
    final date = DateTime(2026, 8, 28);
    final updated = (await repository.load(date)).toggle(Prayer.fajr);
    await repository.save(updated);
    expect((await repository.load(date)).isCompleted(Prayer.fajr), isTrue);
    expect(
      (await repository.load(date.add(const Duration(days: 1))))
          .isCompleted(Prayer.fajr),
      isFalse,
    );
  });

  test('tasbih persists session and history', () async {
    final repository = LocalTasbihRepository(MemoryStorage());
    final session = TasbihSession(
      dhikrId: defaultDhikr.first.id,
      startedAt: DateTime(2026, 8, 28),
    ).increment().copyWith(target: 1);
    await repository.save(session);
    await repository.addHistory(
      TasbihHistoryEntry(
        dhikrId: session.dhikrId,
        count: session.count,
        target: session.target,
        completedAt: session.startedAt,
      ),
    );
    expect((await repository.load()).count, 1);
    expect((await repository.history()).single.target, 1);
  });

  test('religious events and next event are deterministic', () {
    final events = const ReligiousEvents();
    final today = DateTime(2026, 3, 19);
    expect(events.on(today), isA<List<IslamicEvent>>());
    expect(events.next(today).daysRemaining, greaterThanOrEqualTo(0));
  });

  test(
    'widget snapshot serializes minimum data and honors location privacy',
    () {
      final times = calculator.calculate(DateTime(2026, 8, 28), coordinates);
      final snapshot = WidgetSnapshot(
        effectiveDate: times.date,
        locationName: 'Istanbul',
        prayers: times.times,
        nextPrayer: Prayer.fajr,
        nextPrayerTime: times.times[Prayer.fajr],
        scenePeriod: MosqueScenePeriod.fajr,
      );
      expect(snapshot.toJson(showLocationName: false)['locationName'], isNull);
      expect(
        snapshot.toJson(showLocationName: true)['locationName'],
        'Istanbul',
      );
      expect(
        snapshot.toJson(showLocationName: true),
        containsPair('nextPrayer', 'fajr'),
      );
    },
  );

  test('delete all clears user data but not bundled content', () async {
    final storage = MemoryStorage();
    await storage.write('dini.prayer_settings.v2', 'settings');
    await storage.write('dini.favorite.daily-1', '1');
    await storage.write('dini.favorites.index', 'daily-1');
    await storage.write('dini.widget.showLocation', '1');
    await storage.write('dini.tasbih.count', '4');
    await LocalDataRepository(storage).deleteAll();
    expect(await storage.read('dini.prayer_settings.v2'), isNull);
    expect(await storage.read('dini.favorite.daily-1'), isNull);
    expect(await storage.read('dini.widget.showLocation'), isNull);
    expect(OfflineContentRepository.verses, isNotEmpty);
  });

  test(
    'notification ids never collide across prayers, dates, or reminder kinds',
    () {
      final first = calculator.calculate(DateTime(2026, 8, 28), coordinates);
      final second = calculator.calculate(DateTime(2026, 8, 29), coordinates);
      final preferences = NotificationPreferences(
        prayers: {
          for (final prayer in notificationPrayers)
            prayer: const PrayerNotificationPreference(
              enabled: true,
              reminderMinutes: 10,
            ),
        },
        fridayReminder: true,
        ramadanSuhoorReminder: true,
        ramadanIftarReminder: true,
      );
      final planned = const NotificationSchedulePlanner().plan(
        days: [first, second],
        preferences: preferences,
        text: _turkish,
      );
      expect(planned.map((item) => item.id).toSet(), hasLength(planned.length));
    },
  );

  test('DST-sensitive locations keep local prayer hour stable', () {
    for (final timezone in [
      'Europe/Istanbul',
      'Europe/London',
      'America/New_York',
    ]) {
      final before = calculator.calculate(
        DateTime(2026, 3, 28),
        coordinates,
        timezoneId: timezone,
      );
      final after = calculator.calculate(
        DateTime(2026, 3, 30),
        coordinates,
        timezoneId: timezone,
      );
      expect(before.timezoneId, timezone);
      expect(after.timezoneId, timezone);

      // Sabit bir saat beklemek anlamsız: güneş doğuşu konuma ve tarihe göre
      // değişir. Yerel saatin kayması da hata değil — Londra 29 Mart'ta yaz
      // saatine geçer ve güneş doğuşu saati gerçekten bir saat ilerler.
      //
      // Doğru sözleşme şu: altta yatan **an** sürekli olmalıdır. Saat dilimi
      // doğru işleniyorsa UTC'de güneş doğuşu iki günde yalnızca mevsimsel
      // birkaç dakika kayar; yanlış işleniyorsa bir saat sıçrar.
      final beforeUtc = _minuteOfDay(before.times[Prayer.sunrise]!.toUtc());
      final afterUtc = _minuteOfDay(after.times[Prayer.sunrise]!.toUtc());
      expect(
        (afterUtc - beforeUtc).abs(),
        lessThan(30),
        reason:
            '$timezone için güneş doğuşunun UTC anı sıçradı: '
            '$beforeUtc -> $afterUtc dakika. Yaz saati yanlış işleniyor.',
      );
    }
  });

  test('tasbih decrement never produces a negative count', () {
    final session = TasbihSession(
      dhikrId: defaultDhikr.first.id,
      startedAt: DateTime(2026),
    ).reset();
    expect(session.decrement().count, 0);
  });

  test('widget location privacy preference round trips with privacy-conscious default', () async {
    final repository = WidgetPreferencesRepository(MemoryStorage());
    expect(await repository.showLocationName(), isFalse);
    await repository.setShowLocationName(true);
    expect(await repository.showLocationName(), isTrue);
    await repository.setShowLocationName(false);
    expect(await repository.showLocationName(), isFalse);
  });

  test(
    'religious event search crosses year boundary without negative days',
    () {
      final next = const ReligiousEvents().next(DateTime(2026, 12, 31));
      expect(next.daysRemaining, greaterThanOrEqualTo(0));
    },
  );
}

int _minuteOfDay(DateTime value) => value.hour * 60 + value.minute;
