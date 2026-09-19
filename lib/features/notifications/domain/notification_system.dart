import '../../../shared/models/domain.dart';
import '../../calendar/domain/islamic_calendar.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';

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
  ramadanIftarSoon,
}

/// Bildirim metnini kullanıcının diline çeviren işlev.
///
/// Planlayıcı alan katmanındadır ve `BuildContext` göremez; metinler bu yüzden
/// dışarıdan verilir. Daha önce başlık ve gövdeler doğrudan Türkçe yazılıydı,
/// yani İngilizce veya Arapça kullanan bir kişi bildirimi Türkçe alıyordu.
typedef NotificationTextResolver = String Function(
  String key, [
  Map<String, Object> values,
]);

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

  /// Sahur uyarısının imsaktan kaç dakika önce çalacağı.
  ///
  /// Sabit otuz dakikaydı; kalkıp yemek için dar bir süre. Kullanıcı seçer.
  final int suhoorMinutes;

  /// İftardan kaç dakika önce hazırlık uyarısı verileceği. Sıfır ise yalnızca
  /// iftar vaktinde bildirim gönderilir.
  final int iftarMinutes;

  const NotificationPreferences({
    this.prayers = const {},
    this.sound = NotificationSound.defaultSound,
    this.fridayReminder = false,
    this.ramadanSuhoorReminder = false,
    this.ramadanIftarReminder = false,
    this.suhoorMinutes = 45,
    this.iftarMinutes = 30,
  });

  /// Sahur ve iftar uyarıları için seçilebilen süreler (dakika).
  static const suhoorChoices = [30, 45, 60, 90];
  static const iftarChoices = [0, 15, 30, 60];
  PrayerNotificationPreference forPrayer(Prayer prayer) =>
      prayers[prayer] ?? const PrayerNotificationPreference();
  NotificationPreferences copyWith({
    Map<Prayer, PrayerNotificationPreference>? prayers,
    NotificationSound? sound,
    bool? fridayReminder,
    bool? ramadanSuhoorReminder,
    bool? ramadanIftarReminder,
    int? suhoorMinutes,
    int? iftarMinutes,
  }) => NotificationPreferences(
    prayers: prayers ?? this.prayers,
    sound: sound ?? this.sound,
    fridayReminder: fridayReminder ?? this.fridayReminder,
    ramadanSuhoorReminder: ramadanSuhoorReminder ?? this.ramadanSuhoorReminder,
    ramadanIftarReminder: ramadanIftarReminder ?? this.ramadanIftarReminder,
    suhoorMinutes: suhoorMinutes ?? this.suhoorMinutes,
    iftarMinutes: iftarMinutes ?? this.iftarMinutes,
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

  /// Ramazan ayının hicri sıra numarası.
  static const _ramadan = 9;

  List<PlannedNotification> plan({
    required List<PrayerTimes> days,
    required NotificationPreferences preferences,
    required NotificationTextResolver text,
    // Kullanıcının hicri kaydırması buraya ulaşmazsa Ramazan bildirimleri
    // ekranda görünen günden farklı bir günde planlanır.
    IslamicCalendar calendar = const IslamicCalendar(),
    DateTime? notBefore,
  }) {
    final result = <int, PlannedNotification>{};
    final cutoff = notBefore;

    void add({
      required DateTime at,
      required NotificationKind kind,
      required String title,
      required String body,
      Prayer? prayer,
    }) {
      if (cutoff != null && !at.isAfter(cutoff)) return;
      final id = notificationId(at, kind, prayer: prayer);
      result[id] = PlannedNotification(
        id: id,
        prayer: prayer,
        kind: kind,
        scheduledAt: at,
        title: title,
        body: body,
      );
    }

    for (final day in days) {
      for (final prayer in notificationPrayers) {
        final value = day.times[prayer]!;
        final setting = preferences.forPrayer(prayer);
        if (!setting.enabled) continue;

        add(
          at: value,
          kind: NotificationKind.prayer,
          prayer: prayer,
          title: text('prayer.${prayer.name}'),
          body: text('notify.prayerBody'),
        );

        final minutes = setting.reminderMinutes;
        if (minutes != null && minutes > 0) {
          add(
            at: value.subtract(Duration(minutes: minutes)),
            kind: NotificationKind.beforePrayer,
            prayer: prayer,
            title: text('notify.beforeTitle', {
              'prayer': text('prayer.${prayer.name}'),
            }),
            body: text('notify.beforeBody', {'minutes': minutes}),
          );
        }
      }

      if (preferences.fridayReminder && day.date.weekday == DateTime.friday) {
        add(
          at: day.times[Prayer.dhuhr]!.subtract(const Duration(minutes: 60)),
          kind: NotificationKind.friday,
          title: text('notify.fridayTitle'),
          body: text('notify.fridayBody'),
        );
      }

      // Ramazan uyarıları yalnızca Ramazan günlerinde planlanır.
      if (calendar.hijri(day.date).month != _ramadan) continue;

      if (preferences.ramadanSuhoorReminder) {
        final minutes = preferences.suhoorMinutes;
        add(
          at: day.times[Prayer.fajr]!.subtract(Duration(minutes: minutes)),
          kind: NotificationKind.ramadanSuhoor,
          title: text('notify.suhoorTitle'),
          body: text('notify.suhoorBody', {'minutes': minutes}),
        );
      }

      if (preferences.ramadanIftarReminder) {
        final maghrib = day.times[Prayer.maghrib]!;
        final minutes = preferences.iftarMinutes;
        // Hazırlık uyarısı isteğe bağlıdır; sıfır seçilirse yalnızca iftar
        // vaktinde bildirim gider.
        if (minutes > 0) {
          add(
            at: maghrib.subtract(Duration(minutes: minutes)),
            kind: NotificationKind.ramadanIftarSoon,
            title: text('notify.iftarSoonTitle'),
            body: text('notify.iftarSoonBody', {'minutes': minutes}),
          );
        }
        add(
          at: maghrib,
          kind: NotificationKind.ramadanIftar,
          title: text('notify.iftarTitle'),
          body: text('notify.iftarBody'),
        );
      }
    }
    return result.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }
}

/// Bir bildirimin kimliği.
///
/// Aynı gün, aynı tür ve aynı namaz her zaman aynı sayıyı verir; böylece
/// yeniden planlama aynı bildirimi çoğaltmaz.
///
/// Eski şema `gün * 20 + 15 + tür` biçimindeydi ve tür sayısı beşten fazla
/// olduğunda `15 + 5 = 20` ertesi günün ilk kimliğiyle çakışıyordu: iki ayrı
/// bildirim aynı kimliği alır, biri diğerini sessizce silerdi. Slot genişliği
/// artık türlerin iki katından fazla.
int notificationId(DateTime at, NotificationKind kind, {Prayer? prayer}) {
  const kinds = NotificationKind.values;
  // Her (namaz, tür) çifti kendi slotunu alır. Çarpan tür sayısıdır; daha
  // küçük bir çarpan (eskiden 2) yalnızca iki tür namazla eşleştiği sürece
  // çalışır ve üçüncü tür eklendiğinde sessizce çakışır.
  final slot = prayer == null
      ? _specialSlotBase + kind.index
      : prayer.index * kinds.length + kind.index;
  assert(slot < _slotsPerDay, 'Bildirim slotu taştı: $slot');
  final day = at.year * 372 + at.month * 31 + at.day;
  return day * _slotsPerDay + slot;
}

/// Namazlı slotlar 0..35, özel günler 36..41. 48, büyümeye yer bırakır ve
/// kimliği 32 bit tam sayı sınırının çok altında tutar.
const _slotsPerDay = 48;
const _specialSlotBase = 36;

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
    required NotificationTextResolver text,
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
      text: text,
      calendar: settings.calendar,
      notBefore: start,
    );
    for (final item in planned) {
      await service.schedule(item, preferences.sound);
    }
  }
}
