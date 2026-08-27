# STEP 4 — Daily Use Systems

Bu aşama yalnızca `/home/ubuntu/dini_flutter` Flutter projesine uygulanmıştır. Eski Expo projesi değiştirilmemiştir ve satın alma/store entegrasyonu başlatılmamıştır.

## Local notifications

`LocalNotificationService` UI/domain katmanını plugin API’sinden ayırır. `NotificationSchedulePlanner` beş namazı, prayer başına enable/disable tercihini, 5/10/15/30 dakika reminder seçeneklerini, Cuma ve Ramazan foundation hatırlatıcılarını ve duplicate-safe ID üretimini deterministik olarak planlar. Coordinator, seçili calculation method, Asr method, adjustments, location timezone ve DST-aware `TZDateTime` değerlerini koruyarak varsayılan olarak yedi gün ileri planlama yapar. Her reschedule önce mevcut bildirimleri iptal eder; böylece location, method, adjustment, preference ve resume değişikliklerinde duplicate birikmez.

Bildirim izinleri ilk açılışta körlemesine istenmez. Settings ekranı önce yerel hesaplama açıklaması gösterir, sonra platform iznini ister. Varsayılan ses, bundled ses ve sessiz seçenekleri ayrıdır. iOS ve Android arka plan kısıtları nedeniyle tam uzunlukta ezan playback garantisi verilmez.

## Native widgets

Gerçek native dosyalar şunlardır:

- `ios/DiniWidget/DiniWidget.swift`
- `ios/DiniWidget/Info.plist`
- `ios/DiniWidget/DiniWidget.entitlements`
- `ios/Runner/WidgetSnapshotBridge.swift`
- `ios/Runner/Runner.entitlements`
- `android/app/src/main/kotlin/com/dini/dini_flutter/DiniWidgetProvider.kt`
- `android/app/src/main/res/layout/widget_dini.xml`
- `android/app/src/main/res/xml/dini_widget_info.xml`
- `android/app/src/main/AndroidManifest.xml`

Widget snapshot minimum prayer data, effective date, next prayer, scene period ve privacy kontrollü location name içerir. Tracker, tasbih ve favorites paylaşılmaz. iOS App Group `group.com.dini.diniFlutter`, Android ise uygulamanın private shared preferences alanını kullanır. Widget timeline yalnızca prayer transition tarihleri çevresinde güncellenir; permanent background service veya minute-by-minute wakeup yoktur.

## Tracker, tasbih and calendar

Prayer tracker effective local date başına beş prayer durumunu, tasbih seçimi/count/target/haptic/session history’yi ve aylık Gregorian-Hicri calendar ile deterministic religious events’i abstraction-backed local storage üzerinde tutar. Delete All Local Data confirmation’ı settings, tracker, tasbih, favorites, notification ve widget preference verilerini temizler; bundled dini içerikleri silmez.

Android SDK ve macOS/Xcode bu sandbox’ta bulunmadığından native build/runtime doğrulaması yapılamamıştır. Platform çalıştırması yapılmadan native widget runtime’ı PASS sayılmaz.
