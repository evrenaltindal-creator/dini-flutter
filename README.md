# Dini Flutter Foundation

Bu repository, önceki Expo/React Native projesinden bağımsız, taze Flutter/Dart foundation’dır. State yönetimi Riverpod, navigation go_router ve cihaz-içi persistence SharedPreferences abstraction’ı ile hazırlanmıştır. Custom backend, Firebase, Supabase, analytics ve advertising SDK eklenmemiştir.

Feature-first dizinleri `lib/features`, ortak modeller `lib/shared/models`, tema `lib/core/theme`, storage `lib/core/storage` ve router `lib/app` altında tutulur. Prayer calculation, dynamic mosque scene, offline religious content ve local favorites STEP 3 kapsamında uygulanmıştır; native notifications, native widgets ve StoreKit/Google Play Billing kapsam dışındadır.

## Verification

`dart format --set-exit-if-changed .`, `flutter analyze` ve `flutter test` başarılıdır. Android debug build, sandbox’ta Android SDK bulunmadığı için doğrulanamadı. iOS build’i macOS/Xcode gerektirir ve bu ortamda doğrulanmadı.

## STEP 2 — Prayer Engine, Location & Qibla

Prayer times are calculated on-device behind `PrayerTimesCalculator`; no third-party calculation classes leak into the UI. The foundation supports Turkey-oriented, Muslim World League, Umm al-Qura, Egyptian, Karachi and ISNA method enums, with standard and Hanafi Asr contracts. The current foundation calculator is intentionally a deterministic local approximation for architecture validation and must not be labelled as official Diyanet times.

Coordinates are used locally. `DeviceLocationService` requests permission only when automatic mode is selected, returns a safe fallback for disabled/denied location, and accepts validated manual coordinates without geocoding or network lookup. The storage abstraction is preserved so location preference can later be persisted without scattering SharedPreferences calls across widgets.

Qibla bearing is calculated locally from the Kaaba coordinates (21.4225, 39.8262). The Qibla screen subscribes to the magnetometer only while visible, cancels the subscription on dispose, and shows calm fallback guidance when a sensor is unavailable. The implementation has no location upload, remote geocoding, maps, Firebase, Supabase, analytics or advertising dependency.

Date handling uses the selected IANA location timezone through the bundled timezone database. After-Isha explicitly resolves tomorrow’s Fajr, including location-date rollover and DST-aware local construction. The calculator remains a deterministic local approximation for architecture validation, not a replacement for official local timetable data.

## STEP 2 Acceptance Hardening

The deterministic acceptance suite now covers four geographic points (Istanbul, Mecca, London and New York), three calculation method families, prayer ordering, boundary semantics, after-Isha tomorrow-Fajr regression, Qibla normalization and tolerances, coordinate validation, minute adjustments and 12/24-hour display formatting. The explicit boundary rule is that an exact prayer timestamp advances to the following timetable entry.

The engine uses the selected IANA timezone identifier through the bundled timezone database and constructs local prayer boundaries with DST-aware `TZDateTime`. Automatic location uses `geolocator` and safely handles disabled services, denied permissions and denied-forever states, while hardware permission dialogs and GPS behavior remain platform-runtime concerns.

STEP 3’teki MosqueScene, prayer board, offline content cards, Hicri/Cuma/Ramazan durumları ve local favorites uygulanmıştır. Qibla magnetometer subscription yalnızca `QiblaPage` mounted olduğunda başlar ve `dispose` içinde iptal edilir; sensör runtime’ı Linux sandbox’ında doğrulanamaz. Android APK build’i Android SDK bulunmadığı için, iOS build’i ise macOS/Xcode gerektirdiği için doğrulanmamıştır.
