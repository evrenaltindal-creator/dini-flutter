import 'dart:io';

import 'package:dini_flutter/features/notifications/domain/notification_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alarm kipi seçimi', () {
    test('izin varken çalar saat kipi seçilir', () {
      // `alarmClock` kipi AlarmManager.setAlarmClock() kullanır: sistem bunu
      // çalar saat gibi ele alır ve düşük güç kipinde bile zamanında
      // çalıştırır. Agresif pil yönetimi olan cihazlarda gecikmenin önüne
      // geçen tek güvenilir yol budur.
      expect(
        androidScheduleModeFor(ExactAlarmPermission.allowed),
        AndroidScheduleModeChoice.alarmClock,
      );
    });

    test('izin yokken yaklaşık kipe düşülür', () {
      // İzin olmadan tam zamanlı alarm kurmaya çalışmak güvenlik hatasına
      // düşer ve bildirim HİÇ kurulmaz. Geç gelen bildirim, hiç gelmeyenden
      // iyidir.
      expect(
        androidScheduleModeFor(ExactAlarmPermission.denied),
        AndroidScheduleModeChoice.inexact,
      );
    });

    test('durum bilinmiyorsa da yaklaşık kip seçilir', () {
      // Bilinmeyeni "izin var" saymak, bildirimin sessizce hiç kurulmamasına
      // yol açardı.
      expect(
        androidScheduleModeFor(ExactAlarmPermission.unknown),
        AndroidScheduleModeChoice.inexact,
      );
    });

    test('her izin durumunun bir karşılığı var', () {
      // Yeni bir durum eklenirse bu test derlenmeye devam eder ama switch
      // eksik kalırsa analiz hatası verir; yine de kapsamı burada sabitliyoruz.
      for (final status in ExactAlarmPermission.values) {
        expect(androidScheduleModeFor(status), isNotNull);
      }
    });
  });

  group('AndroidManifest', () {
    late String manifest;

    setUpAll(() {
      manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
    });

    test('tam zamanlı alarm izni bildirilmiş', () {
      // Bildirilmeden tam zamanlı alarm kurmak Android 12+ cihazlarda
      // güvenlik hatasına düşer: kullanıcı hiç bildirim almaz.
      expect(
        manifest,
        contains('android.permission.SCHEDULE_EXACT_ALARM'),
        reason: 'İzin manifestte yok; eklentinin manifesti de bunu getirmiyor.',
      );
    });

    test('yeniden başlatma ve saat değişimi alıcıları duruyor', () {
      // Telefon yeniden başlayınca ya da saat dilimi değişince alarmlar
      // yeniden kurulmazsa bildirimler sessizce kaybolur.
      for (final action in [
        'android.intent.action.BOOT_COMPLETED',
        'android.intent.action.TIME_SET',
        'android.intent.action.TIMEZONE_CHANGED',
      ]) {
        expect(manifest, contains(action), reason: '$action alıcısı yok.');
      }
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    test('USE_EXACT_ALARM bilerek bildirilmemiş', () {
      // O izin kullanıcı onayı istemez ama Google Play politikası gereği
      // yalnızca çekirdek işlevi alarm/takvim olan uygulamalara açıktır;
      // incelemede reddedilme riski taşır. Eklenmesi bilinçli bir karar
      // olmalı, kazara değil.
      expect(
        manifest,
        isNot(contains('android.permission.USE_EXACT_ALARM')),
        reason:
            'USE_EXACT_ALARM eklenmiş. Play politikası riski değerlendirilip '
            'bu test bilinçli olarak güncellenmeli.',
      );
    });
  });
}
