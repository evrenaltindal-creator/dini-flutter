# Dini Flutter Foundation TODO

- [x] Yeni bağımsız Flutter/Dart proje klasörü oluşturuldu
- [x] pubspec.yaml ile Riverpod, go_router ve SharedPreferences tanımlandı
- [x] lib/app, core, shared ve features feature-first yapısı kuruldu
- [x] Türkçe varsayılan locale state ve English genişleme noktası hazırlandı
- [x] Light/dark/system merkezi design system oluşturuldu
- [x] go_router bottom navigation ve temel rotalar bağlandı
- [x] Home foundation reusable Flutter widget’larıyla oluşturuldu
- [x] Settings’ten Premium ve Privacy Center rotaları bağlandı
- [x] Privacy foundation ve destructive olmayan delete placeholder eklendi
- [x] Strongly typed future domain contracts ve storage abstraction eklendi
- [x] No-network policy ve MIGRATION_REFERENCE.md yazıldı
- [x] Flutter format, analyze ve test kontrolleri çalıştırıldı
- [x] Android build denendi; Android SDK yokluğu nedeniyle NOT VERIFIED
- [x] iOS build durumu macOS/Xcode yokluğu nedeniyle NOT VERIFIED

## STEP 2 — Prayer Engine, Location & Qibla

- [x] Strongly typed Prayer/PrayerTimes/NextPrayerState/Coordinates domain modellerini geliştirmek
- [x] On-device Turkey, MWL, Umm al-Qura, Egyptian, Karachi ve ISNA calculation method engine’i
- [x] Standard ve Hanafi Asr hesaplaması
- [x] Local timezone/date, midnight, after-Isha ve next-day Fajr mantığı
- [x] Automatic location permission/service fallback ve manual coordinate preference
- [x] Coordinates’ın cihaz dışına çıkmadığını doğrulamak
- [x] Prayer calculation settings ekranı ve local persistence
- [x] Riverpod location/settings/prayer state providers
- [x] Home’u gerçek yerel vakitler, current/next ve countdown ile bağlamak
- [x] Local Qibla bearing calculator ve testleri
- [x] Qibla compass/sensor lifecycle ve graceful fallback
- [x] Istanbul, Mecca, London ve New York deterministic prayer/Qibla testleri
- [x] Flutter kalite kapısı ve STEP 2 teknik dokümantasyonu

## STEP 2 ACCEPTANCE HARDENING — STEP 3 Yok

- [x] Prayer ordering ve Turkey/MWL/Umm al-Qura test matrisini genişletmek
- [x] Tüm next-prayer boundary semantiklerini deterministic test etmek
- [x] After-Isha’da yarının yeniden hesaplandığını regression test etmek
- [x] Europe/Istanbul, Europe/London ve America/New_York timezone/DST stratejisini denetlemek
- [x] Automatic location gerçek plugin davranışı ve hata durumlarını test/raporlamak
- [x] Location network leak ve networking dependency audit’ini yenilemek
- [x] Qibla bearing normalization, edge case ve şehir testlerini genişletmek
- [x] Qibla sensor runtime sınırını ve lifecycle kanıtını raporlamak
- [x] Riverpod recalculation, date rollover ve app resume mimarisini harden etmek
- [x] Turkey labeling, 12/24 format ve minute adjustment durumunu gerçek kanıtla sınıflandırmak
- [x] Settings persistence ve Home provider/widget testlerini eklemek
- [x] Error state testleri ve exact acceptance report’u hazırlamak

## STEP 3 — Dynamic Mosque Experience (STEP 4 Yok)

- [x] Strongly typed MosqueScene period/state resolver
- [x] Prayer-boundary based sun progression, sky, moon/stars and mosque lighting
- [x] Layered Flutter-native MosqueScene renderer with CustomPainter
- [x] Actual prayer board and current/next hierarchy in Home
- [x] Small sourced offline DailyVerse, DailyHadith and DailyDua repository
- [x] Deterministic same-date content selection
- [x] Expand/favorite/copy/share content card interactions
- [x] Local favorites persistence through storage abstraction
- [x] Local Hijri date, Friday mode and Ramadan mode states
- [x] Reduced-motion, text scaling, screen reader labels and responsive layout
- [x] Scene/content/calendar/Home widget tests
- [x] No-network audit, STEP 3 documentation and exact final report

## STEP 3 FINAL ACCEPTANCE — SPECIFICATION DENETİMİ

- [x] Specification dosyasındaki tüm STEP 3 acceptance maddelerini sırayla denetlemek
- [x] Denetimde bulunan STEP 3 kusurlarını düzeltmek
- [x] Specification’ın istediği test ve kalite komutlarını çalıştırmak
- [x] Android SDK/macOS-Xcode yokluğu durumunu NOT VERIFIED olarak raporlamak
- [x] Specification formatındaki FINAL REPORT’u hazırlamak

## STEP 4 — Native Widgets, Local Scheduling & Worship Tracking

- [x] STEP 4 specification dosyasındaki tüm maddeleri sırayla denetlemek
- [x] Local notification scheduling domain ve izin akışını uygulamak
- [x] Prayer tracker local persistence ve Home/feature akışını uygulamak
- [x] Tasbih local persistence ve etkileşimli ekranını uygulamak
- [x] iOS WidgetKit native extension ve shared local snapshot sözleşmesini oluşturmak
- [x] Android AppWidget/Glance native widget ve shared local snapshot sözleşmesini oluşturmak
- [x] Widget güncelleme sözleşmesini local-first ve backend’siz tamamlamak
- [x] STEP 4 responsive/accessibility ve regression testlerini eklemek
- [x] Specification kalite komutlarını çalıştırmak ve tüm hataları düzeltmek
- [x] Specification formatındaki STEP 4 FINAL REPORT’u hazırlamak

## STEP 4 FINAL ACCEPTANCE — FOLLOW-UP SPECIFICATION

- [x] Yeni specification dosyasını önceki STEP 4 uygulamasıyla karşılaştırmak
- [x] Eksik veya yanlış STEP 4 implementasyonlarını düzeltmek
- [x] Specification’ın istediği eksik acceptance testlerini eklemek
- [x] dart format, flutter analyze ve flutter test kalite kapısını yeniden çalıştırmak
- [x] Native build/runtime durumlarını doğrulayıp yalnızca doğrulanabilen sonuçları raporlamak
- [x] Yeni specification FINAL REPORT formatını aynen hazırlamak

## STEP 5 — Premium, StoreKit & Google Play Billing

- [x] STEP 5 specification dosyasındaki tüm maddeleri sırayla denetlemek
- [x] Premium entitlement domain ve local cache akışını uygulamak
- [x] StoreKit native köprüsünü oluşturmak
- [x] Google Play Billing native köprüsünü oluşturmak
- [x] Mağaza ürün metadata/fiyatlarını runtime mağaza sorgusuna bağlamak
- [x] Purchase, restore ve entitlement state akışlarını uygulamak
- [x] Delete All Local Data’nın yalnızca local entitlement cache temizlediğini doğrulamak
- [x] Premium UI’da core dini özellikleri ücretsiz korumak ve hardcoded fiyat göstermemek
- [x] Diyanet URL’sini güncel doğrulama durumuna göre güvenli biçimde ele almak
- [x] STEP 5 acceptance testlerini eklemek
- [x] dart format, flutter analyze ve flutter test kalite kapısını çalıştırmak
- [x] Native build/runtime durumlarını doğrulayıp STEP 5 FINAL REPORT hazırlamak

## FINAL PRODUCTION ACCEPTANCE — AUDIT ONLY

- [x] Önceki FINAL PRODUCTION ACCEPTANCE specification’ındaki tüm audit maddelerini karşılaştırmak
- [x] Yalnızca audit kapsamında tespit edilen kod/test/config kusurlarını düzeltmek
- [x] Native/runtime doğrulama yapılmayan alanları PASS göstermemek
- [x] Placeholder product ID, Diyanet URL ve production-readiness blocker’larını doğrulamak
- [x] dart format --set-exit-if-changed ., flutter analyze ve flutter test komutlarını çalıştırmak
- [x] Specification FINAL REPORT formatını aynen güncellemek

## Android Release Acceptance Phase 1

- [x] Android SDK/JDK toolchain durumunu doğrula
- [x] Debug APK build durumunu doğrula
- [x] Release AAB build durumunu doğrula
- [x] Native widget ve local notification kod durumunu doğrula
- [x] Android emulator kurulum ve erişim durumunu doğrula
- [x] Kalan Android release blocker’larını raporla
- [x] Android Release Acceptance Phase 1 çıktısını teslim et

## ANDROID TOOLCHAIN BOOTSTRAP

- [x] Mevcut Flutter SDK kurulumlarını ve PATH durumunu bul
- [x] Projenin Android SDK/Gradle/JDK gereksinimlerini oku
- [x] Flutter stable SDK’yı güvenli kullanıcı dizinine kur veya mevcut kurulumu kullan
- [x] Android command-line tools, platform-tools, emulator, platform ve build-tools kur
- [x] Android lisanslarını doğrula ve kabul et
- [x] JDK/Gradle/AGP uyumluluğunu doğrula
- [x] ADB ve emulator/AVD kurulumunu doğrula
- [x] Flutter clean, pub get, format, analyze ve test kalite kapısını çalıştır
- [x] Debug APK build, SHA-256 ve boyut doğrulamasını yap
- [x] APK install, app launch ve logcat smoke testini yap
- [x] Release AAB build durumunu doğrula
- [x] Release signing durumunu audit et; production key üretme
- [x] Toolchain persistence dokümantasyonunu hazırla
- [x] Exact Android Toolchain Bootstrap FINAL REPORT’u teslim et

## ANDROID REAL DEVICE ACCEPTANCE

- [x] Gerçek Android cihaz ADB bağlantısını ve cihaz metadatasını doğrula — cihaz bağlı değil
- [x] Debug APK install durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] App launch ve logcat crash/ANR durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Home, Settings, Qibla, Tracker, Tasbih, Calendar, Premium ve Privacy Center smoke test durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Location permission ve manual fallback runtime durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Qibla sensor runtime durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Notification permission, local delivery, reminder ve rescheduling durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Android reboot runtime durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Compact/medium widget, privacy ve process-death durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Prayer tracker, tasbih, calendar ve Delete All Local Data runtime durumunu doğrula — NOT VERIFIED, cihaz bağlı değil
- [x] Accessibility ve logcat privacy durumunu doğrula — runtime NOT VERIFIED
- [x] Google Play Billing runtime durumunu gerçek store kanıtına göre sınıflandır — NOT VERIFIED, Play Console setup/device yok
- [x] Quality gate durumunu doğrula — format/analyze/test PASS
- [x] Exact Android Real Device Acceptance FINAL REPORT’unu teslim et

## ANDROID STUDIO RUNTIME ACCEPTANCE

- [x] Android Studio, Flutter/Dart plugin ve Device Manager durumunu doğrula — Android Studio/Device Manager mevcut değil
- [x] AVD ve emulator runtime durumunu doğrula — AVD mevcut, /dev/kvm nedeniyle BLOCKED
- [x] Quality gate’i çalıştır — PASS
- [x] Debug APK build/install/launch ve logcat durumunu doğrula — build PASS, runtime NOT VERIFIED
- [x] Home, Settings, location, Qibla math/UI ve runtime akışlarını doğrula — NOT VERIFIED
- [x] Notification, reminder, rescheduling ve reboot akışlarını doğrula — NOT VERIFIED
- [x] Compact/medium widget, privacy ve process-death akışlarını doğrula — NOT VERIFIED
- [x] Prayer tracker, tasbih, calendar, favorites, copy/share ve delete-all akışlarını doğrula — NOT VERIFIED
- [x] Premium, Google Play Billing, accessibility ve reduced-motion durumlarını doğrula — NOT VERIFIED
- [x] Logcat privacy ve network runtime audit’ini doğrula — runtime NOT VERIFIED; statik audit yapıldı
- [x] Exact Android Studio Runtime Acceptance FINAL REPORT’unu teslim et

## ANDROID STUDIO ENVIRONMENT VERIFICATION

- [x] Android Studio binary ve kurulum yollarını ayrıntılı tara — bulunamadı
- [x] GUI display değişkenlerini doğrula — DISPLAY mevcut
- [x] KVM durumunu doğrula — /dev/kvm mevcut değil
- [x] Android Studio varsa sürüm, SDK bağlantısı ve AVD görünürlüğünü doğrula — uygulanamadı; Android Studio bulunamadı
- [x] Runtime acceptance başlatmadan exact environment raporunu teslim et

## LOCAL ANDROID STUDIO HANDOFF

- [ ] Quality gate’i yeniden çalıştır
- [ ] Generated/cache dosyalarını handoff paketinden hariç tut
- [ ] Secret/credential/keystore dosyaları için paketleme audit’i yap
- [ ] LOCAL_ANDROID_STUDIO_SETUP.md rehberini oluştur
- [ ] Temiz dini_flutter kök ZIP arşivini oluştur
- [ ] ZIP boyutunu, SHA-256 değerini ve içeriğini doğrula
- [ ] Exact handoff raporunu teslim et
