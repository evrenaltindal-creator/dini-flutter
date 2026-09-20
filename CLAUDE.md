# CLAUDE.md — Dini Flutter için çalışma kuralları

Bu dosya, bu depoda çalışan her Claude oturumu için bağlayıcı kısa kılavuzdur.
Projenin tam haritası için `ARCHITECTURE.md`, sıradaki işler ve gerekçeleri
için `ROADMAP.md` dosyasını oku.

## Proje özeti

**Namaz Yolu** (`dini_flutter` paketi), Türkçe/İngilizce/Arapça namaz
vakitleri uygulamasıdır. Görünen ad üç dilde `appTitle` anahtarından gelir
(en: Prayer Path, ar: طريق الصلاة); paket kimliği `com.dini.dini_flutter`
mağaza kimliğidir ve değiştirilmez.
Flutter + Riverpod + go_router. **Tamamen cihaz içi (offline-first) çalışır.**

## Değişmez kurallar (ihlal etme, önce sor)

1. **Backend yok.** Custom backend, Firebase, Supabase, analytics, reklam SDK'sı,
   crash reporting veya uzak API çağrısı eklenmez. Namaz vakitleri, kıble, hicri
   takvim ve günlük içerik cihazda hesaplanır/paketlenir. Tek istisna:
   `url_launcher` ile açılan Diyanet soru sayfası ve mağaza (StoreKit / Play Billing).
2. **Konum cihazdan çıkmaz.** Koordinatlar hiçbir yere gönderilmez; geocoding yok.
3. **Üç dil zorunlu.** Kullanıcıya görünen her metin
   `lib/core/localization/app_localizations.dart` içindeki `_strings` haritasına
   **`tr`, `en` ve `ar` için birlikte** eklenir. Şu an üç dilde de tam olarak
   360 anahtar var; `localization_test.dart` bu pariteyi zorunlu kılar.
   Widget'ta düz string yazma; `context.l10n.text('key')` kullan.
4. **RTL bozulmaz.** Arapça yön desteği `MaterialApp.supportedLocales` içindeki
   `Locale('ar')` + `GlobalWidgetsLocalizations.delegate` üzerinden otomatik gelir.
   `EdgeInsets.only(left/right)` yerine `EdgeInsetsDirectional`, `Alignment` yerine
   `AlignmentDirectional`, `Row`'da sabit hizalama yerine yön duyarlı çözüm kullan.
   `TextDirection`'ı elle sabitleme.
5. **Kapsam dışına çıkma.** Görev "sadece X ekranı" diyorsa diğer feature
   klasörlerine, temaya, router'a ve native (ios/android) dosyalarına dokunma.
6. **Sürüm/imza dosyaları.** `ios/Runner.xcodeproj/project.pbxproj`,
   entitlements, bundle id'ler ve `.github/workflows/*` istenmedikçe değiştirilmez.

## Kalite kapısı — CI'ın çalıştırdığı tam komutlar

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .   # EN SIK CI HATASI
flutter analyze
flutter test --reporter expanded
```

- CI Flutter sürümü **3.47.1 (stable)** ve onun getirdiği **Dart 3.13.1**.
  Paketin SDK kısıtı `^3.13.1`.
- `dart format` bir kapıdır: push'tan önce **mutlaka `dart format .` çalıştır**.
  Formatlanmamış tek bir satır tüm CI'ı kırar.
- **Formatter sürümü önemlidir.** Dart 3.12 ile 3.13 satırları farklı kırar;
  3.12 ile formatlanmış kod CI'da (3.13.1) "Changed ..." verip build'i düşürür.
  Bu tuzak ard arda dört CI koşusunu kırdı. Yerel Dart'ın sürümünü
  `dart --version` ile doğrula; 3.13.1 değilse formatlama sonucuna güvenme.
- Remote container'da Flutter SDK kurulu gelmez. CI ile birebir aynı sürümü
  kurmak için:

  ```bash
  curl -sSL -o /tmp/flutter.tar.xz \
    https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz
  tar -xf /tmp/flutter.tar.xz -C /tmp
  export PATH="/tmp/flutter/bin:$PATH"   # dart --version -> 3.13.1
  ```

  İndirme ~1.5 GB ve birkaç dakika sürer. Kuramadıysan **testleri
  çalıştıramadığını raporunda açıkça yaz**, "geçti" deme. Kod yazarken mevcut
  test dosyalarındaki stili örnek al.
- Depoda şu an 41 dosyada 497 test var; hepsi geçmelidir.

## Git akışı

1. İşe başlamadan `git fetch origin main` ile son kodu al.
2. Ayrı bir branch'te çalış (oturuma atanan `claude/...` branch'i).
3. `dart format .` → analiz/test → commit → `git push -u origin <branch>`.
4. **Açıkça istenmedikçe pull request açma.** Kullanıcı değişikliği kendisi inceler.
5. Commit mesajları: `feat(quran): ...`, `fix(ci): ...`, `style: ...` biçimindedir.

## Nereye ne yazılır

| İhtiyaç | Dosya |
| --- | --- |
| Yeni metin (3 dil) | `lib/core/localization/app_localizations.dart` |
| Yeni sayfa / rota / alt menü | `lib/app/router.dart` |
| Renk, tipografi, kart/nav teması | `lib/core/theme/app_theme.dart` |
| Namaz hesap mantığı | `lib/features/prayer_times/domain/` |
| Kalıcı veri | `lib/core/storage/local_storage.dart` soyutlaması üzerinden |
| Ortak model/enum | `lib/shared/models/domain.dart` |
| Test | `test/` |
| Uygulama simgesi | Kaynak tasarım `assets/branding/app_icon_source.png`; PNG'ler `tool/generate_app_icon.py` ile üretilir (elle düzenleme) |
| Bildirim tonu | `tool/generate_notification_tone.py` |

## Bilinmesi gereken tuzaklar

- `lib/app/router.dart` 979 satırdır; `HomePage`, `SettingsPage`, `PrivacyPage`,
  `AboutPage` ve `PlaceholderPage` bu dosyanın içindedir. Yeni büyük ekranı
  buraya gömme, `lib/features/<alan>/presentation/` altına aç ve router'dan bağla.
- **`/quran` rotası `QuranComingSoonPage`'tir.** Kuran ekranı henüz yazılmadı;
  meal telif nedeniyle bilinçli olarak ertelendi.
- `main.dart` özel bir `LocalizationsDelegate` kaydetmez; `AppLocalizations`
  doğrudan `Localizations.localeOf(context)` okur. Bu tasarımı bozma.
- `SharedPreferences` doğrudan widget'larda kullanılmaz; `LocalStorage` üzerinden
  gidilir. Test ortamında `MemoryStorage` devreye girer.
- Native widget köprüsü (`MethodChannel('dini/widget_snapshot')`) testte
  `MissingPluginException` fırlatır ve sessizce yutulur — bu bilinçlidir.
- Mağaza ürün kimlikleri `--dart-define` ile gelir; `.dev` ile biten placeholder
  değerler TestFlight workflow'unda reddedilir.
- Yeni asset eklersen `pubspec.yaml` içindeki `assets:` listesini güncelle.
- **Konum artık ayarlanabiliyor** (Ayarlar → Konum): cihazdan otomatik ya da
  paketlenmiş listeden şehir. Saat dilimi en yakın şehirden çözülür; koordinatı
  değiştirip dilimi sabit bırakmak Berlin'deki kullanıcıya Berlin koordinatını
  İstanbul saatiyle gösterirdi. Kaydetmenin tek yolu `savePrayerSettings`'tir
  ve **sıra önemlidir**: alarmlar widget'tan önce yeniden kurulur.
- **Tam zamanlı alarm izni bildirildi.** İzin varken `alarmClock` kipi
  kullanılır, yokken `inexactAllowWhileIdle`'a düşülür — izinsiz tam zamanlı
  alarm kurmaya çalışmak bildirimi tamamen düşürür. `USE_EXACT_ALARM`
  **bilerek** bildirilmedi (Play politikası riski); bir test kazara
  eklenmesini engelliyor.
- **İlk açılış akışı vardır** (`/onboarding`): dil → konum → bildirim izni →
  pil rehberi. `main.dart` bayrağı okuyup başlangıç rotasını verir; router
  `createRouter()` fabrikasıdır, üst düzey `appRouter` yoktur.
- **Vakitler kullanıcının SEÇTİĞİ yerin gününe göre hesaplanır.** Motor
  kendisine verilen tarihin gün/ay/yıl alanlarını olduğu gibi kullanır;
  `prayerTimesProvider` bu yüzden saati önce şehrin saat dilimine çevirir.
  Ham `DateTime.now()` geçilirse cihazın dilimi farklı olduğunda gece yarısı
  civarında bütün vakitler bir gün kayar.
- **Şimdiki zaman `clockProvider` üzerinden okunur.** Doğrudan
  `DateTime.now()` çağıran ekran testte sabitlenemez.
- **Ramazan gecesi akşam ezanıyla başlar** (`ramadanNightDate`): mahya ve
  teravih akşamdan sonra ertesi günü gösterir.
- **Her sayfanın arkasında cami durur.** Rotayı `MosqueBackdrop` ile
  sarmalamak YETMEZ: temanın zemin rengi opaktır ve sayfanın kendi düz
  `Scaffold`'u sahneyi tamamen örter. Yeni sayfa `BackdropScaffold`
  kullanmalı (ya da `backgroundColor: Colors.transparent` vermeli);
  `backdrop_coverage_test.dart` bütün rotaları dolaşıp bunu bekçiler.
- **Widget'a veri `pushWidgetSnapshot` ile yazılır.** Yalnızca
  `WidgetSnapshotService.refresh()` çağırmak uzantıya "çizelgeni yenile"
  demektir; okuyacağı değerleri yazmaz. Vakitleri etkileyen her yol
  (açılış, ayar kaydı, konum adı anahtarı) anlık görüntüyü yeniden
  göndermelidir.
- **Canlı etkinliğin (Live Activity) Swift tarafı DERLENMEDİ.**
  `PrayerLiveActivity.swift` ve `LiveActivityBridge.swift` yazıldı ama
  `project.pbxproj` değiştirilmediği için Xcode hedeflerine eklenmedi
  (`ROADMAP.md` 2.1). Dart tarafı süren etkinliğin aynasını cihazda tutar;
  bu ayna olmadan uygulama her açıldığında ikinci bir sayaç açılır.
- **Mahya yalnızca Ramazan gecelerinde yanar.** Minare çapaları görselden
  ölçüldü ve `BoxFit.cover` kırpmasına göre çözülür; `assets/scenes/*.png`
  dosyalarını farklı oranda bir görselle değiştirirsen mahya boşluğa asılır
  (`mahya_test.dart` oranı bekçiler).
- Simge ve bildirim tonu PNG/WAV dosyaları `tool/` altındaki betiklerden
  üretilir. Dosyaları elle düzenleme; betiği değiştirip yeniden çalıştır.
  Betikler `pip install Pillow` ister, başka bağımlılıkları yoktur.
- **Simgenin kaynağı `assets/branding/app_icon_source.png`** (1024×1024,
  degrade zemin). **Tam kenar olmalı**: kare, saydamlıksız, köşeleri
  yuvarlatılmamış ve etrafına "saydamlık" damaları çizilmemiş — betik bunları
  kontrol edip hata veriyor, sessizce kabul etmiyor. `pubspec.yaml` varlık
  listesine eklenmez: uygulama onu çalışma anında yüklemez.
- **Android uyarlanabilir simgede zemin düz renk DEĞİL**, üretilen bir PNG
  katmandır (`ic_launcher_background.png`): tasarımın zemini degrade olduğu
  için düz renk, küçültülen ön planın kenarında renk farkı bırakıyordu. Ön
  plan da yalnızca altın hatları taşır; zemini de taşısaydı madalyonun
  çevresinde daire şeklinde dikiş görünürdü. Küçültme oranı ölçülen içerik
  yayılımından hesaplanır (`CONTENT_EXTENT`), tasarım değişirse yeniden
  ölçülmeli.
- **Kıble açısı gerçek (coğrafi) kuzeye göredir.** Android'in pusulası
  manyetik kuzeye göre ölçer; `MagneticDeclinationService` farkı
  `GeomagneticField` üzerinden kapatır. iOS zaten `trueHeading` verir.
  Bu ayrımı kaldırma, ok birkaç derece kayar.
- **Android bildirim kanalının sesi oluşturulduktan sonra değiştirilemez.**
  Bu yüzden her ses seçeneği kendi kanal kimliğini taşır; kimlikleri
  birleştirirsen kullanıcı sesi değiştirdiğinde hiçbir şey olmaz.
- `LocalPrayerTimesCalculator` varsayılanları `PrayerSettings`
  varsayılanlarıyla aynı olmalıdır; ayrıldıklarında ikindi elli dakikaya
  varan fark verir. `prayer_engine_test.dart` bunu bekçiler.
