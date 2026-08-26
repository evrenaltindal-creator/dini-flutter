import '../../../shared/models/domain.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../calendar/domain/islamic_calendar.dart';

const notificationPrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

enum NotificationSound { defaultSound, bundled, silent }

enum NotificationPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

enum NotificationKind {
  prayer,
  beforePrayer,
  friday,
  ramadanSuhoor,
  ramadanIftar,
}

class PrayerNotificationPreference {
  final bool enabled;
  final int? reminderMinutes;
  const PrayerNotificationPreference({
    this.enabled = false,
    this.reminderMinutes,
  });
  PrayerNotificationPreference copyWith({
    bool? enabled,
    int? reminderMinutes,
    bool clearReminder = false,
  }) => PrayerNotificationPreference(
    enabled: enabled ?? this.enabled,
    reminderMinutes: clearReminder
        ? null
        : (reminderMinutes ?? this.reminderMinutes),
  );
}

class NotificationPreferences {
  final Map<Prayer, PrayerNotificationPreference> prayers;
  final NotificationSound sound;
  final bool fridayReminder, ramadanSuhoorReminder, ramadanIftarReminder;
  const NotificationPreferences({
    this.prayers = const {},
    this.sound = NotificationSound.defaultSound,
    this.fridayReminder = false,
    this.ramadanSuhoorReminder = false,
    this.ramadanIftarReminder = false,
  });
  PrayerNotificationPreference forPrayer(Prayer prayer) =>
      prayers[prayer] ?? const PrayerNotificationPreference();
  NotificationPreferences copyWith({
    Map<Prayer, PrayerNotificationPreference>? prayers,
    NotificationSound? sound,
    bool? fridayReminder,
    bool? ramadanSuhoorReminder,
    bool? ramadanIftarReminder,
  }) => NotificationPreferences(
    prayers: prayers ?? this.prayers,
    sound: sound ?? this.sound,
    fridayReminder: fridayReminder ?? this.fridayReminder,
    ramadanSuhoorReminder: ramadanSuhoorReminder ?? this.ramadanSuhoorReminder,
    ramadanIftarReminder: ramadanIftarReminder ?? this.ramadanIftarReminder,
  );
}

class PlannedNotification {
  final int id;
  final Prayer? prayer;
  final NotificationKind kind;
  final DateTime scheduledAt;
  final String title, body;
  const PlannedNotification({
    required this.id,
    required this.prayer,
    required this.kind,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });
}

abstract class LocalNotificationService {
  Future<void> initialize();
  Future<NotificationPermissionStatus> requestPermission();
  Future<void> cancelAll();
  Future<void> schedule(
    PlannedNotification notification,
    NotificationSound sound,
  );
}

class NotificationSchedulePlanner {
  const NotificationSchedulePlanner();
  List<PlannedNotification> plan({
    required List<PrayerTimes> days,
    required NotificationPreferences preferences,
    DateTime? notBefore,
  }) {
    final result = <int, PlannedNotification>{};
    final cutoff = notBefore;
    for (final day in days) {
      for (final prayer in notificationPrayers) {
        final value = day.times[prayer]!;
        final setting = preferences.forPrayer(prayer);
        if (!setting.enabled) continue;
        if (cutoff == null || value.isAfter(cutoff)) {
          final item = PlannedNotification(
            id: _id(value, prayer, NotificationKind.prayer),
            prayer: prayer,
            kind: NotificationKind.prayer,
            scheduledAt: value,
            title: _label(prayer),
            body: 'Namaz vakti geldi.',
          );
          result[item.id] = item;
        }
        final minutes = setting.reminderMinutes;
        if (minutes != null && minutes > 0) {
          final reminder = value.subtract(Duration(minutes: minutes));
          if ((cutoff == null || reminder.isAfter(cutoff)) &&
              reminder.isAfter(DateTime(2000))) {
            final item = PlannedNotification(
              id: _id(value, prayer, NotificationKind.beforePrayer),
              prayer: prayer,
              kind: NotificationKind.beforePrayer,
              scheduledAt: reminder,
              title: '${_label(prayer)} yaklaşıyor',
              body: '$minutes dakika sonra namaz vakti.',
            );
            result[item.id] = item;
          }
        }
      }
      final fajr = day.times[Prayer.fajr]!;
      final maghrib = day.times[Prayer.maghrib]!;
      final hijri = const IslamicCalendar().hijri(day.date);
      if (preferences.fridayReminder && day.date.weekday == DateTime.friday) {
        final at = day.times[Prayer.dhuhr]!.subtract(
          const Duration(minutes: 60),
        );
        if (cutoff == null || at.isAfter(cutoff)) {
          final item = PlannedNotification(
            id: _specialId(at, NotificationKind.friday),
            prayer: null,
            kind: NotificationKind.friday,
            scheduledAt: at,
            title: 'Cuma hatırlatıcısı',
            body: 'Cuma için hazırlık zamanı.',
          );
          result[item.id] = item;
        }
      }
      if (hijri.month == 9 && preferences.ramadanSuhoorReminder) {
        final at = fajr.subtract(const Duration(minutes: 30));
        if (cutoff == null || at.isAfter(cutoff)) {
          final item = PlannedNotification(
            id: _specialId(at, NotificationKind.ramadanSuhoor),
            prayer: null,
            kind: NotificationKind.ramadanSuhoor,
            scheduledAt: at,
            title: 'Sahur yaklaşıyor',
            body: 'Sahur için 30 dakika kaldı.',
          );
          result[item.id] = item;
        }
      }
      if (hijri.month == 9 && preferences.ramadanIftarReminder) {
        if (cutoff == null || maghrib.isAfter(cutoff)) {
          final item = PlannedNotification(
            id: _specialId(maghrib, NotificationKind.ramadanIftar),
            prayer: null,
            kind: NotificationKind.ramadanIftar,
            scheduledAt: maghrib,
            title: 'İftar vakti',
            body: 'Hesaplanan yerel Maghrib vakti geldi.',
          );
          result[item.id] = item;
        }
      }
    }
    return result.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  int _id(DateTime value, Prayer prayer, NotificationKind kind) =>
      value.year * 100000 +
      value.month * 1000 +
      value.day * 20 +
      prayer.index * 2 +
      kind.index;
  int _specialId(DateTime value, NotificationKind kind) =>
      value.year * 100000 +
      value.month * 1000 +
      value.day * 20 +
      15 +
      kind.index;
  String _label(Prayer prayer) => switch (prayer) {
    Prayer.fajr => 'Sabah',
    Prayer.dhuhr => 'Öğle',
    Prayer.asr => 'İkindi',
    Prayer.maghrib => 'Akşam',
    Prayer.isha => 'Yatsı',
    Prayer.sunrise => 'Güneş doğuşu',
  };
}

class PrayerNotificationCoordinator {
  final LocalNotificationService service;
  final PrayerTimesCalculator calculator;
  final NotificationSchedulePlanner planner;
  const PrayerNotificationCoordinator({
    required this.service,
    required this.calculator,
    this.planner = const NotificationSchedulePlanner(),
  });
  Future<void> reschedule({
    required DateTime start,
    required Coordinates coordinates,
    required PrayerSettings settings,
    required NotificationPreferences preferences,
    int daysAhead = 7,
  }) async {
    await service.cancelAll();
    final hasAnyReminder =
        preferences.prayers.values.any((value) => value.enabled) ||
        preferences.fridayReminder ||
        preferences.ramadanSuhoorReminder ||
        preferences.ramadanIftarReminder;
    if (!hasAnyReminder) return;
    final days = List.generate(daysAhead + 1, (index) {
      final date = DateTime(start.year, start.month, start.day + index);
      return calculator.calculate(
        date,
        coordinates,
        method: settings.method,
        asrMethod: settings.asrMethod,
        adjustments: settings.adjustments,
        timezoneId: settings.location.timezoneId ?? 'Europe/Istanbul',
      );
    });
    final planned = planner.plan(
      days: days,
      preferences: preferences,
      notBefore: start,
    );
    for (final item in planned) {
      await service.schedule(item, preferences.sound);
    }
  }
}
