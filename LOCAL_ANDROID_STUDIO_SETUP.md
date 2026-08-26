# Local Android Studio Setup

Bu paket, **Dini Flutter** projesini kullanıcının yerel bilgisayarındaki Android Studio’da açıp test etmek için hazırlanmıştır. Proje local-first/offline-first mimariyi korur; bu handoff yeni bir uygulama özelliği eklemez.

## Gereksinimler

Yerel bilgisayarda Flutter stable SDK, Android Studio, Android SDK, Android SDK Platform-Tools, Android SDK Build-Tools, Android Emulator ve proje tarafından kullanılan Android platformu kurulu olmalıdır. Flutter SDK sürümü için önerilen taban, handoff hazırlanırken kullanılan **Flutter 3.47.1 / Dart 3.13.1** sürümüdür. Projedeki `android/gradle/wrapper/gradle-wrapper.properties` ve `android/settings.gradle.kts` dosyaları Gradle/Android Gradle Plugin uyumluluğu için kaynak kabul edilmelidir.

Android Studio içinde **Flutter** ve **Dart** plugin’lerinin kurulu ve etkin olduğunu kontrol edin. Device Manager ile bir Android emulator oluşturun veya USB debugging açık gerçek bir Android cihaz bağlayın. Production signing keystore ve Google Play ürün kimlikleri bu pakete dahil değildir.

## Projeyi açma

1. ZIP arşivini açın ve içindeki `dini_flutter` kök klasörünü çalışma alanına çıkarın.
2. Android Studio’da **Open** seçeneğini kullanarak doğrudan `dini_flutter` klasörünü açın. Yalnızca `dini_flutter/android` alt klasörünü ayrı bir proje olarak açmayın; Flutter kökü açılmalıdır.
3. Android Studio’nun Gradle sync işleminin tamamlanmasını bekleyin.
4. Terminalde proje kökünde aşağıdaki komutları çalıştırın:

```bash
cd /path/to/dini_flutter
flutter pub get
flutter doctor -v
```

`flutter doctor -v` çıktısında Android toolchain’in yerel SDK path’iyle hazır olduğunu doğrulayın. Gerekirse Android Studio > Settings > Languages & Frameworks > Flutter içinden Flutter SDK path’ini seçin.

## Çalıştırma ve build

Bir emulator veya bağlı gerçek Android cihaz seçtikten sonra:

```bash
flutter run
```

Debug APK üretmek için:

```bash
flutter build apk --debug
```

APK çıktısı:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Release AAB üretmeden önce gerçek production keystore/signing yapılandırmasını güvenli şekilde sağlayın. Repository’deki mevcut debug signing yapılandırması mağaza yayını için production signing olarak kabul edilmemelidir.

## Test komutları

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Beklenen test suite kapsamı handoff hazırlanırken **58 test** idi. Test çıktısı, yerel Flutter/Dart sürümünüz ve bağımlılık çözümünüz ile yeniden doğrulanmalıdır.

## Android runtime acceptance checklist

Aşağıdaki akışları emulator veya gerçek cihaz üzerinde, her maddeyi gerçek gözlem ve logcat kanıtıyla kontrol edin:

| Alan | Kontrol |
|---|---|
| Home | Namaz panosu, current/next prayer, dinamik mosque scene ve günlük içerik kartları |
| Settings | Location, prayer calculation, notifications, theme, language, Premium ve Privacy Center rotaları |
| Location | İzin ver/reddet, yeniden deneme ve manual location fallback |
| Qibla | Bearing/UI, compass fallback ve gerçek cihaz sensörü destekleniyorsa heading davranışı |
| Notifications | İzin, local schedule, before-prayer reminder, cancel/reschedule ve timezone değişimi |
| Compact widget | Gerçek home-screen widget picker’dan ekleme ve next prayer/time görüntüsü |
| Medium widget | Gerçek widget’ta next prayer ve günlük timetable görüntüsü |
| Prayer Tracker | Check, uncheck, restart ve local persistence |
| Tasbih | Increment, decrement/undo, reset, target, non-negative counter ve persistence |
| Calendar | Previous/next month, today, Gregorian/Hijri selection ve religious event marker |
| Delete All Local Data | Favorites, tracker, tasbih, settings, notifications ve widget preferences temizliği; safe defaults dönüşü |

Runtime testleri sırasında `FATAL EXCEPTION`, `AndroidRuntime`, `MissingPluginException`, `ClassNotFoundException`, `SecurityException` ve ANR kayıtlarını kontrol edin. Precise coordinates, tracker/tasbih history, purchase token ve kişisel ayarlar logcat’e yazılmamalıdır. Google Play Billing runtime ancak Play Console internal testing, gerçek product ID’leri ve tester hesabıyla doğrulanabilir.

## Bilinen handoff sınırları

Bu paket Android Studio’nun kendisini, Android SDK’yı, emulator system image’ını, production keystore’u, credentials’ları veya gerçek store secrets’larını içermez. Native notification/widget kodu ve StoreKit/Google Play Billing kodu kaynakta korunmuştur; gerçek cihaz/store runtime doğrulaması yerel acceptance ortamında yapılmalıdır.
