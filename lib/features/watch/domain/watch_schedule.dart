import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../shared/models/domain.dart';

/// Saate gönderilen günlerin sayısı.
///
/// Saat vakitleri kendisi hesaplamaz, telefondan alır. Telefon uzaktayken
/// (yolculuk, telefon evde) saatin boş kalmaması için iki hafta gönderilir;
/// bu, WatchConnectivity uygulama bağlamının boyut sınırının çok altındadır.
const watchScheduleDays = 14;

/// Saatin telefondan aldığı arayüz metinlerinin anahtarları.
const watchTextKeys = [
  'watch.next',
  'watch.today',
  'watch.stale',
  // Kadran göstergesinin galerideki açıklaması.
  'watch.complication',
  // Saatteki tesbih.
  'home.tasbih',
  'tasbih.target',
  'tasbih.reset',
];

/// Saatte gösterilen vakitler; güneş doğuşu namaz vakti değildir, ama
/// imsakın bittiğini gösterdiği için listede kalır.
const watchPrayers = [
  Prayer.fajr,
  Prayer.sunrise,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// Bir günün vakitleri.
class WatchDay {
  /// Seçilen şehrin takvim günü (yalnızca yıl/ay/gün anlamlı).
  final DateTime date;
  final Map<Prayer, DateTime> times;

  const WatchDay({required this.date, required this.times});
}

/// Saate giden çizelge.
class WatchSchedule {
  final List<WatchDay> days;

  /// Vakit adları kullanıcının dilinde. Saatin uygulamanın çeviri
  /// haritasına erişimi yoktur; adlar hazır gitmezse saatte "maghrib" yazar.
  final Map<Prayer, String> labels;

  /// Konum adı; kullanıcı widget'ta konum adını kapattıysa gönderilmez.
  final String? locationName;

  /// Saatin kendi arayüz metinleri ("Sıradaki", "Bugün"). Saat uygulamasının
  /// üç dilli çeviri haritası yoktur; metinler de telefondan hazır gelir.
  final Map<String, String> texts;

  final DateTime generatedAt;

  /// Seçilen şehrin saat dilimi (IANA). Saat vakitleri bu dilimde yazar;
  /// yoksa yolculukta telefonla saat farklı saat gösterirdi — telefon
  /// vakitleri seçilen şehrin duvar saatinde gösterir.
  final String timezoneId;

  const WatchSchedule({
    required this.days,
    required this.labels,
    required this.locationName,
    required this.generatedAt,
    required this.timezoneId,
    this.texts = const {},
  });

  /// Saate gidecek sözlük.
  ///
  /// İki kural, ikisi de telefonda pahalıya öğrenildi:
  ///
  /// - **Null yok.** JSON'daki null Swift'te `NSNull` olur; property-list
  ///   olmayan bir değer `UserDefaults`'a yazılınca uygulama çöküyordu
  ///   (TestFlight 1.0.0 (10)). WatchConnectivity'nin uygulama bağlamı da
  ///   property-list ister. Değer yoksa anahtar hiç yazılmaz.
  /// - **Tarih metni yok.** Anlar Unix saniyesi olarak gider. ISO metni
  ///   Swift tarafında `ISO8601DateFormatter`'ın seçeneklerine bağlıydı ve
  ///   saliseler yüzünden widget'ta bütün vakitler "—" görünmüştü.
  Map<String, Object> toPayload() => {
    'version': 1,
    'generatedAt': _seconds(generatedAt),
    'timezoneId': timezoneId,
    if (locationName != null && locationName!.isNotEmpty)
      'locationName': locationName!,
    'texts': texts,
    'labels': {
      for (final prayer in watchPrayers)
        if (labels[prayer] != null) prayer.name: labels[prayer]!,
    },
    'days': [
      for (final day in days)
        {
          'date':
              '${day.date.year.toString().padLeft(4, '0')}-'
              '${day.date.month.toString().padLeft(2, '0')}-'
              '${day.date.day.toString().padLeft(2, '0')}',
          for (final prayer in watchPrayers)
            if (day.times[prayer] != null)
              prayer.name: _seconds(day.times[prayer]!),
        },
    ],
  };

  static int _seconds(DateTime value) =>
      value.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}

/// Çizelgeyi saate ileten kanal.
///
/// Saat eşleşmemişse ya da saat uygulaması kurulu değilse native taraf
/// sessizce geçer. Saat ikincil bir yüzeydir; hata açılışı ya da ayar
/// kaydını durdurmamalı.
class WatchScheduleService {
  static const channel = MethodChannel('dini/watch');
  const WatchScheduleService();

  Future<void> send(WatchSchedule schedule) async {
    try {
      await channel.invokeMethod('updateSchedule', {
        'schedule': jsonEncode(schedule.toPayload()),
      });
    } on MissingPluginException {
      // Saat köprüsü Linux/test ortamında ve Android'de yok.
    } on PlatformException {
      // Saat eşleşmemiş ya da oturum açılamadı; bir sonraki gönderimde
      // yeniden denenir.
    }
  }
}
