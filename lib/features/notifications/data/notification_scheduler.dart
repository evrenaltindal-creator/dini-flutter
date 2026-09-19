import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/local_storage.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../domain/notification_system.dart';
import 'flutter_local_notification_service.dart';
import 'notification_preferences_repository.dart';

/// Bildirim servisi. Testlerde sahte bir servisle değiştirilebilsin diye
/// provider üzerinden verilir; daha önce ekranın içinde doğrudan
/// yaratıldığı için planlama davranışı test edilemiyordu.
final notificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => FlutterLocalNotificationService(),
);

/// Kayıtlı tercihlere göre namaz bildirimlerini yeniden planlar.
///
/// Tek giriş noktasıdır ve üç yerden çağrılır: uygulama açılışı, alarm ekranı
/// ve hesaplama ayarlarının kaydedilmesi. Daha önce bu kurulum iki ayrı yerde
/// elle tekrarlanıyordu.
///
/// Planlama, bildirim izni olmasa bile yapılır: izin verilmemişse işletim
/// sistemi bildirimi göstermez, ama kullanıcı izni sonradan verdiğinde
/// alarmlar zaten kurulmuş olur. İzni beklemek, alarmın hiç kurulmamasına
/// yol açıyordu.
///
/// [PrayerNotificationCoordinator] sekiz günlük bir pencere planlar; bu yüzden
/// uygulama her açılışta yeniden planlar ve pencere kayar.
Future<void> reschedulePrayerNotifications({
  required LocalStorage storage,
  required PrayerSettings settings,
  NotificationPreferences? preferences,
  LocalNotificationService? service,
  Locale? locale,
}) async {
  final values =
      preferences ?? await NotificationPreferencesRepository(storage).load();
  final notifications = service ?? FlutterLocalNotificationService();
  await notifications.initialize();
  // Bildirim metni kullanıcının dilinde olmalı. Planlayıcı alan katmanındadır
  // ve `BuildContext` göremez; çözümleyici buradan verilir.
  final strings = AppLocalizations(locale ?? await savedLocale(storage));
  await PrayerNotificationCoordinator(
    service: notifications,
    calculator: const LocalPrayerTimesCalculator(),
  ).reschedule(
    start: TimezoneService.inLocation(
      settings.location.timezoneId ?? 'Europe/Istanbul',
      DateTime.now(),
    ),
    coordinates: Coordinates(
      settings.location.latitude ?? 41.0082,
      settings.location.longitude ?? 28.9784,
    ),
    settings: settings,
    preferences: values,
    text: strings.text,
  );
}

/// Kullanıcının kaydettiği dil. Hiç seçilmemişse ya da tanınmayan bir kod
/// kayıtlıysa Türkçe döner.
Future<Locale> savedLocale(LocalStorage storage) async {
  final code = await storage.read(localePreferenceKey);
  final supported = AppLocalizations.supportedLocales.map(
    (locale) => locale.languageCode,
  );
  return Locale(supported.contains(code) ? code! : 'tr');
}
