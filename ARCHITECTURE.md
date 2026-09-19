# ARCHITECTURE.md — Dini Flutter proje haritası

Bu belge deponun tamamını anlatır. Günlük çalışma kuralları için `CLAUDE.md`,
adım adım geliştirme geçmişi için `STEP*.md` ve `todo.md` dosyalarına bak.

---

## 1. Genel tablo

| Konu | Değer |
| --- | --- |
| Paket adı | `dini_flutter` |
| Sürüm | `1.0.0+1` |
| Dart SDK | `^3.13.1` |
| CI Flutter | `3.47.1` (stable) |
| State yönetimi | `flutter_riverpod` ^2.6.1 |
| Navigasyon | `go_router` ^16.2.0 (`StatefulShellRoute.indexedStack`) |
| Kalıcılık | `shared_preferences` ^2.5.3, `LocalStorage` soyutlaması arkasında |
| Diller | `tr` (varsayılan), `en`, `ar` (RTL) |
| Ağ | **Yok.** Backend, Firebase, Supabase, analytics, reklam yok |

Diğer bağımlılıklar: `geolocator` (konum), `sensors_plus` (pusula),
`timezone` (IANA veritabanı), `flutter_local_notifications`, `in_app_purchase`,
`share_plus`, `url_launcher`, `flutter_localizations`.

### Mimari ilke

Feature-first katmanlama. Her `lib/features/<alan>/` klasörü kendi içinde
üç katmana ayrılır:

```
domain/        saf Dart; Flutter'a ve I/O'ya bağımlı değil; testlerin ana hedefi
data/          repository, platform servisi, MethodChannel köprüsü
presentation/  sayfalar, widget'lar, Riverpod provider'ları
```

Bu ayrım kasıtlıdır: hesaplama mantığı (`domain`) widget ağacı kurmadan
test edilebilir. Yeni mantık yazarken önce `domain`'e koy.

---

## 2. Dosya haritası

### Uygulama çekirdeği

| Dosya | Görev |
| --- | --- |
| `lib/main.dart` | Giriş noktası. `SharedPreferences` yükler, kayıtlı dili okur, `ProviderScope` override'larını kurar, `MaterialApp.router`'ı yapılandırır. `themeModeProvider`, `localeProvider` ve `localePreferenceKey` burada tanımlıdır. |
| `lib/app/router.dart` | **979 satır.** Tüm rotalar, alt menü (`NavigationBar`) ve `HomePage`, `SettingsPage`, `PremiumPage`, `PrivacyPage`, `AboutPage`, `PlaceholderPage` sayfaları. |
| `lib/core/localization/app_localizations.dart` | `tr`/`en`/`ar` için 242'şer anahtarlık sabit `_strings` haritası, `{placeholder}` değiştirme, `context.l10n` extension'ı. Parite `localization_test.dart` ile zorunludur. |
| `lib/core/theme/app_theme.dart` | Material 3 light/dark tema. Tohum renk `#0b3d3a`, ikincil `#cda45e`. Kart, navigasyon çubuğu, chip ve metin temaları. |
| `lib/core/storage/local_storage.dart` | `LocalStorage` arayüzü + `SharedPreferencesStorage`. |
| `lib/core/storage/storage_provider.dart` | `localStorageProvider`; `SharedPreferences` yoksa `MemoryStorage`'a düşer (test yolu). |
| `lib/core/storage/local_data_repository.dart` | "Tüm yerel veriyi sil" akışı; paketlenmiş dinî içeriği korur. |
| `lib/shared/models/domain.dart` | Ortak enum ve modeller: `Prayer`, `PrayerCalculationMethod`, `AsrMethod`, `PrayerTimes`, `LocationPreference`, `DailyVerse/Hadith/Dua`, `PrayerTrackingEntry`, `TasbihSession`, `PremiumEntitlement`. |

### Rota tablosu (`lib/app/router.dart`)

Alt menüde beş sekme — `StatefulShellRoute.indexedStack`, sekme durumu korunur:

| # | Rota | Ekran | Menü anahtarı |
| --- | --- | --- | --- |
| 0 | `/` | `HomePage` (cami sahnesi + vakitler) | `nav.home` |
| 1 | `/quran` | `QuranComingSoonPage` — **henüz yazılmadı**, meal telif nedeniyle ertelendi | `nav.quran` |
| 2 | `/worship` | `TasbihPage` | `nav.worship` |
| 3 | `/calendar` | `CalendarPage` | `nav.calendar` |
| 4 | `/settings` | `SettingsPage` | `nav.settings` |

Menü dışı rotalar: `/premium`, `/privacy`, `/about`, `/qibla`, `/tasbih`,
`/tracker`, `/notifications`, `/imsakiye`.

Ana sayfada alt menü camiye uyacak şekilde koyu/altın renklerle
(`NavigationBarTheme` override) çizilir; diğer sekmelerde tema varsayılanı kullanılır.

---

## 3. Feature'lar

### `features/prayer_times/` — namaz vakitleri (çekirdek)

- `domain/prayer_engine.dart` — `PrayerTimesCalculator` arayüzü ve
  `LocalPrayerTimesCalculator`. Altı hesaplama yöntemi (Diyanet, MWL,
  Umm al-Qura, Egyptian, Karachi, ISNA) ve iki ikindi içtihadı (standard/hanafi).
  **Varsayılan ikindi `standard`'dır** ve `PrayerSettings` ile aynı olmalıdır:
  Diyanet ikindiyi asr-ı evvel ile yayımlar, Hanefî ile aradaki fark elli
  dakikayı bulur.
  `nextPrayerState()` sıradaki vakti ve kalan süreyi üretir; **tam vakit anı bir
  sonraki vakte ilerler** (sınır kuralı testlerle sabitlenmiştir).
- `domain/prayer_settings.dart` — `PrayerSettings`, `PrayerAdjustments`
  (dakika bazlı elle düzeltme), `LocationMode`, `formatPrayerTime()` (12/24 saat
  yalnızca gösterimdir, hesaplamayı etkilemez).
- `domain/timezone_service.dart` — paketlenmiş IANA veritabanı; DST'ye duyarlı
  `TZDateTime` üretimi, gün dönümü.
- `domain/prayer_clock.dart` — `Clock`/`SystemClock`/`FakeClock` ve
  `PrayerDayController` (uygulama resume olduğunda gereksiz yeniden hesaplama yapmaz).
- `data/location_service.dart` — `geolocator`; servis kapalı, izin reddedilmiş ve
  kalıcı reddedilmiş durumlarında güvenli fallback. Koordinat cihazdan çıkmaz.
- `data/prayer_settings_repository.dart` — ayarların yerel serileştirilmesi.
- `domain/monthly_timetable.dart` — bir ayın tamamı için günlük vakitler
  (imsakiye). Ekrandan bağımsızdır ve tek gün hesabıyla birebir örtüşmesi
  test edilir.
- `presentation/providers.dart` — `prayerTimesProvider`, `nextPrayerProvider`,
  `effectivePrayerSettingsProvider`, `monthlyTimetableProvider` (ay bazlı
  `family`). Varsayılan konum İstanbul (41.0082, 28.9784).
- `presentation/imsakiye_page.dart` — aylık çizelge; bugünün satırına
  kaydırılmış açılır, satır yüksekliği sabit olduğu için konum doğrudan
  hesaplanabilir.
- `presentation/settings_controller.dart` — `sharedPreferencesProvider` (override
  zorunlu) ve `PrayerSettingsController` (`AsyncNotifier`).

> Hesaplayıcı bilinçli olarak yerel bir yaklaşımdır ve resmî Diyanet takvimi
> olarak etiketlenmemelidir. Yine de `diyanet_reference_test.dart`, Ankara için
> yayımlanan haftalık tabloya üç dakika toleransla bağlıdır; motorun
> gerçeklikten kopmasını yakalayan tek testtir.

### `features/home/` — cami sahnesi

- `domain/mosque_scene_state.dart` — `MosqueScenePeriod` (preFajrNight, fajr,
  sunrise, day, dhuhr, asr, goldenHour, maghrib, ishaNight) ve
  `MosqueSceneStateResolver`; gerçek namaz sınırlarından güneş ilerlemesi,
  ay/yıldız görünürlüğü ve gökyüzü geçişi hesaplar.
- `presentation/mosque_scene.dart` — katmanlı render; `assets/scenes/` altındaki
  dört arka plan (`mosque_dawn`, `mosque_day`, `mosque_asr`, `mosque_night`)
  üzerine `CustomPainter` ile güneş/ay/yıldız çizilir. Azaltılmış hareket
  (reduced motion) ve metin ölçeklemesi dikkate alınır.

### `features/qibla/` — kıble

`domain/qibla_calculator.dart` Kâbe (21.4225, 39.8262) için büyük daire açısını
hesaplar; sonuç **gerçek (coğrafi) kuzeye** göredir.
`domain/compass_north.dart` + `data/magnetic_declination.dart` cihaz okumasını
gerçek kuzeye çevirir: iOS `CLHeading.trueHeading` verdiği için düzeltme
gerekmez, Android `SensorManager.getOrientation` ile manyetik kuzeye göre ölçer
ve sapma `GeomagneticField` üzerinden (`dini/geomagnetic` kanalı) okunur. Bu
ayrım olmadan ok Android'de sapma kadar sistematik olarak kayar.
`presentation/qibla_page.dart` magnetometreye **yalnızca sayfa açıkken** abone olur,
`dispose` içinde iptal eder; sensör yoksa sakin bir yönlendirme gösterir. Ekran
hangi kuzeye göre ölçtüğünü yazar ve sapma bilindiğinde manyetik karşılığı da
gösterir.

### `features/calendar/` — hicri takvim

`islamic_calendar.dart` offline tablosal hicri dönüşüm (resmî ilandan bir gün
sapabilir — bu uyarı `settings.hijriNotice` metninde kullanıcıya gösterilir).
`religious_events.dart` dinî günler ve sıradaki olay.

### `features/content/` — günün içeriği

`content_repository.dart` paketlenmiş ayet/hadis/dua; seçim tarihe göre
**deterministiktir** (aynı gün aynı içerik). `content_card.dart` genişletme,
favorileme, kopyalama ve paylaşma etkileşimlerini sağlar; favoriler yereldir.

### `features/tasbih/`, `features/tracker/`

Tesbih sayacı (`defaultDhikr` listesi, oturum + geçmiş, sayaç asla negatife
düşmez) ve namaz takibi (etkin yerel tarihe göre kayıt, aç/kapa). İkisi de
`LocalStorage` üzerinden kalıcıdır.

### `features/notifications/`

- `domain/notification_system.dart` — `NotificationSchedulePlanner` (beş vakit,
  önceden hatırlatma ofsetleri, Cuma, sahur ve iftar bildirimleri) ve
  `PrayerNotificationCoordinator` (tekrarı engeller, yatsıdan sonra ertesi günü
  planlar). Ses seçenekleri: `defaultSound`, `bundled`, `silent`.
- `data/flutter_local_notification_service.dart` — `flutter_local_notifications`
  sarmalayıcısı; izin durumları `NotificationPermissionStatus` ile modellenir.
- `presentation/notification_settings_page.dart` — izin akışı ve tercihler.

### `features/premium/`

`domain/premium.dart` — `EntitlementStatus`, `PurchaseProduct`,
`PremiumTheme`, `FreeFeaturePolicy`. **Tüm temel ibadet özellikleri ücretsizdir**;
premium yalnızca ek sahneler, widget biçimleri ve gelişmiş yerel istatistiklerdir.
`StoreProductIds` değerleri `--dart-define` ile gelir; varsayılanlar `.dev` ile
biter ve TestFlight workflow'u bunları reddeder.
`data/purchase_service.dart` `in_app_purchase` ile konuşur;
`data/entitlement_repository.dart` durumu yerel olarak önbelleğe alır.

### `features/widgets/` — ana ekran widget'ları

`domain/widget_snapshot.dart` — `WidgetSnapshot` modeli ve `WidgetSnapshotService`;
`MethodChannel('dini/widget_snapshot')` üzerinden `updateSnapshot`,
`clearSnapshot`, `refreshWidgets` çağırır. Test/Linux ortamında
`MissingPluginException` sessizce yutulur.
`data/widget_preferences_repository.dart` — "widget'ta şehir adını göster"
tercihi; gizlilik gereği **varsayılan kapalıdır**.

### `features/info/diyanet_flow.dart`

`https://kurul.diyanet.gov.tr/Soru/Sor` adresini harici tarayıcıda açar.
Uygulama Diyanet'e bağlı değildir ve dinî hüküm vermez.

---

## 4. Yerelleştirme ve RTL

`AppLocalizations` üretilmiş ARB dosyaları kullanmaz; elle tutulan
`static const Map<String, Map<String, String>> _strings` yapısıdır.

- Erişim: `context.l10n.text('nav.home')`,
  `context.l10n.text('home.remaining', {'hours': 1, 'minutes': 20})`,
  `context.l10n.prayer('maghrib')`, `context.l10n.month(3)`.
- Bilinmeyen dil veya eksik anahtar Türkçeye, o da yoksa anahtarın kendisine düşer.
- **`main.dart` özel bir `LocalizationsDelegate` kaydetmez.** `AppLocalizations.of`
  doğrudan `Localizations.localeOf(context)` okur; delegate listesinde yalnızca
  `GlobalMaterial/Widgets/CupertinoLocalizations` vardır.
- RTL bundan gelir: `supportedLocales` içinde `Locale('ar')` olduğu için Flutter
  Arapçada `Directionality`'yi `rtl` yapar. Bunu elle sabitleme.
- Dil seçimi `dini.locale` anahtarıyla saklanır ve açılışta okunur; değişiklik
  `localeProvider` üzerinden anında uygulanır.

---

## 5. Native taraf

### iOS (`ios/`)

- Ana hedef `com.dini.diniFlutter`, WidgetKit uzantısı
  `com.dini.diniFlutter.widget`, dağıtım hedefi iOS 17.0.
- Paylaşılan App Group: **`group.com.dini.diniFlutter`** (her iki entitlements
  dosyasında tanımlı). Anlık görüntü bu grubun `UserDefaults`'ına yazılır.
- `Runner/WidgetSnapshotBridge.swift` MethodChannel'ı karşılar ve
  `WidgetCenter.shared.reloadTimelines(ofKind: "DiniPrayerWidget")` çağırır.
- `DiniWidget/DiniWidget.swift` widget'ı çizer. Uzantı
  `NSExtensionPrincipalClass` **bildirmemelidir** (CI bunu doğrular).
- `PrivacyInfo.xcprivacy` her iki hedefte mevcuttur.

### Android (`android/`)

`DiniWidgetProvider.kt` + `res/layout/widget_dini.xml` ve
`res/xml/dini_widget_info.xml` ile AppWidget sağlanır; `MainActivity.kt` Flutter
tarafını bağlar ve iki kanal yayımlar: `dini/widget_snapshot` ve
`dini/geomagnetic` (manyetik sapma).

Başlatıcı simgesi hem eski PNG'ler hem de `mipmap-anydpi-v26/ic_launcher.xml`
ile uyarlanabilir katman olarak sağlanır; zemin rengi `values/colors.xml`
içindedir. Bildirim sesi `res/raw/notification_tone.wav` olarak derlemeye girer.
Her ses seçeneği **ayrı bir kanal kimliği** taşır, çünkü Android 8'den beri bir
kanalın sesi oluşturulduktan sonra değiştirilemez.

---

## 6. Testler (`test/`)

| Dosya | Kapsam |
| --- | --- |
| `widget_test.dart`, `foundation_test.dart` | Uygulama açılıyor, ana sayfa ve Premium/Privacy rotaları çalışıyor |
| `localization_test.dart` | `en`/`ar` metinleri mevcut; Arapçada `Directionality` **rtl** |
| `step2_test.dart` | Vakit sıralaması, yatsı sonrası ertesi gün sabah, kıble açısı |
| `step2_acceptance_test.dart` | Dört şehir × üç yöntem matrisi, sınır semantiği, koordinat doğrulama, 12/24 biçim |
| `step2_final_hardening_test.dart` | Londra/New York DST, elle seçilen saat dilimi, gün dönümü, resume, ayar kalıcılığı |
| `step3_dynamic_mosque_test.dart` | Sahne çözümleyici her sınırda değişir, güneş ilerlemesi, deterministik günlük içerik, Cuma mantığı |
| `mosque_scene_widget_test.dart` | Her dönem doğru sahne görselini kullanır |
| `step3_responsive_widget_test.dart` | Farklı genişliklerde layout taşması yok, büyük metin ölçeğinde bilgi korunur |
| `step4_acceptance_test.dart` | Bildirim planlayıcı, koordinatör, tracker, tesbih, dinî günler, "tümünü sil", widget gizliliği |
| `step5_acceptance_test.dart` | Ücretsiz özellik politikası, ürün eşlemesi, premium tema kapısı |
| `prayer_engine_test.dart` | Motor koordinatı ve tarihi gerçekten kullanıyor; mevsim, boylam, mezhep, yöntem, kutup bölgeleri, varsayılan parite |
| `diyanet_reference_test.dart` | Ankara için yayımlanan haftalık tabloya üç dakika toleransla bağlılık |
| `imsakiye_test.dart` | Ay uzunlukları ve artık yıl, çizelgenin tek gün hesabıyla örtüşmesi, ekranın üç dilde 320-430 dp arasında çizilmesi |
| `compass_north_test.dart` | Manyetik/gerçek kuzey çevrimi, sapma okunamadığında güvenli davranış, ekranın iki açıyı da göstermesi |
| `app_icon_test.dart` | Simge dosyaları PNG başlığından doğrulanır: boyut, alfa kanalı, varsayılan Flutter simgesine dönüş |
| `notification_sound_test.dart` | Ham kaynağın varlığı, iOS kurulumu, ses başına ayrı kanal |
| `recitation_content_test.dart` | Namaz metinleri kaynaksız veya yarım olamaz; üç dilde çözülür |
| `worship_responsive_test.dart` | İbadet sekmeleri ekrana sığar, rehber ve okunacak metinler üç dilde taşmaz |
| `tasbih_history_test.dart`, `tracker_date_test.dart`, `qibla_needle_test.dart`, `launch_mode_test.dart`, `screen_coverage_test.dart`, `notification_scheduling_test.dart`, `worship_guide_test.dart` | İlgili ekranların davranış testleri |

Testler ağ kullanmaz; `MemoryStorage` ve `FakeClock` ile deterministiktir.
Yeni bir ekran eklerken en az bir davranış testi + (metin eklediysen) yerelleştirme
kontrolü ekle.

---

## 7. CI/CD (`.github/workflows/`)

### `ci.yml` — `main`'e push ve her pull request

1. **quality** (ubuntu): `flutter pub get` →
   `dart format --output=none --set-exit-if-changed .` → `flutter analyze` →
   `flutter test --reporter expanded`.
2. **ios-unsigned** (macos-26, Xcode 26.6): imzasız release build ve
   `Runner.app/PlugIns/DiniWidgetExtension.appex` varlığının doğrulanması.

> `dart format` kapısı en sık kırılan adımdır. Push öncesi `dart format .` çalıştır.

### `ios-testflight.yml` — yalnızca elle (`workflow_dispatch`)

`testflight` GitHub Environment'ını kullanır. Sırasıyla: yapılandırma doğrulaması
(eksik secret veya `.dev` ürün kimliği varsa durur) → kalite kapısı →
App Store Connect imzalama dosyaları → App Store Connect'ten sonraki build
numarası → `flutter build ipa` (ürün kimlikleri `--dart-define` ile) → IPA ve
WidgetKit uzantısı doğrulaması → `app-store-connect publish` (sürüm notları
`TESTFLIGHT_NOTES.txt`, locale `tr`).

Gerekli değişkenler: `APP_STORE_APPLE_ID`, `TESTFLIGHT_INTERNAL_GROUP`,
`DINI_IOS_{MONTHLY,YEARLY,LIFETIME}_PRODUCT_ID`.
Gerekli secret'lar: `APP_STORE_CONNECT_ISSUER_ID`,
`APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_PRIVATE_KEY`,
`CERTIFICATE_PRIVATE_KEY`.

`codemagic.yaml` alternatif bir CI yapılandırması olarak depoda durur.

---

## 8. Gizlilik duruşu

Namaz hesaplaması ve konum kullanımı cihazda kalır. Takip, tesbih, favoriler ve
bildirim planı yerel olarak saklanır. Widget verisi yalnızca işletim sistemi
uzantısıyla paylaşılır. Satın almalar Apple/Google altyapısı üzerindendir.
Özel sunucu, analytics veya reklam takibi yoktur. Gizlilik Merkezi'ndeki
"tüm yerel veriyi sil" akışı kullanıcı verisini temizler, paketlenmiş dinî
içeriği korur.

---

## 9. Yeni ekran nasıl eklenir

1. `lib/features/<alan>/domain/` altına saf Dart mantığını yaz.
2. Kalıcılık gerekiyorsa `data/` altında `LocalStorage` kullanan bir repository aç.
3. `presentation/<alan>_page.dart` içinde ekranı ve Riverpod provider'larını yaz.
4. Metinleri `app_localizations.dart` içine **`tr`, `en` ve `ar` için** ekle.
5. `lib/app/router.dart` içinde `GoRoute` (veya menü sekmesi) olarak bağla.
6. `test/` altına davranış testi ekle.
7. `dart format .` → `flutter analyze` → `flutter test` → commit → push.

Görsel varlıklar elle düzenlenmez: uygulama simgesi `tool/generate_app_icon.py`,
bildirim tonu `tool/generate_notification_tone.py` ile üretilir.

Sıradaki büyük iş: `/quran` rotasındaki "yakında" ekranı yerine gerçek
Kuran ekranı. Meal telif nedeniyle bekletiliyor.
