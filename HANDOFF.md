# HANDOFF — Neler yaptık, nerede kaldık

Son güncelleme: 2026-09-12 · Oturum: Claude Code (remote, Linux konteyner)
Branch: `claude/worship-stabilization` · Taban: `codex/worship-guide` (`e7ec770`)

---

## 1. Devralma doğrulaması

`codex/worship-guide` çekildi, `e7ec770` ve temiz çalışma ağacı doğrulandı.
Codex'in bildirdiği doğrulama sonuçları **bağımsız olarak yeniden üretildi ve
doğru çıktı**: format 59 dosya / 0 değişiklik, analyze temiz, 70/70 test geçti.

## 2. Bulunan sorunlar ve gerçek sebepleri

### a) Dördüncü ibadet sekmesi ekran dışında (kullanıcı göremiyor)

`WorshipHubPage` içindeki `TabBar` `isScrollable: true` + `TabAlignment.start`
ile kuruluydu. Etiketler uzun olduğu için ("Namaz nasıl kılınır?", "Abdest nasıl
alınır?") dört sekme hiçbir telefon genişliğine sığmıyordu.

Ölçülen değerler: 390 dp ekranda 4. sekmenin sağ kenarı **814.8** (ekran 390),
Arapça RTL'de 3. sekmenin sol kenarı **-89.0**. Yani "Alarmlar" sekmesi üç dilde
de görünmez durumdaydı.

Bu bir taşma *istisnası* üretmediği için mevcut testler yakalamıyordu.

### b) Alarmlar sekmesi açılınca `LateInitializationError`

Sekme erişilebilir hale gelince ortaya çıktı — daha önce hiç çalıştırılmamıştı.
`NotificationSettingsView.initState` içinde `service.initialize()` korumasız
çağrılıyor; bildirim eklentisi kayıtlı olmayan bir platformda hata doğrudan
UI'a sızıyordu.

### c) Açılış tekbiri kullanıcının sesini eziyordu

`audioplayers` hiçbir `AudioContext` verilmeden kullanılmıştı. Paketin kendi
varsayılanları (doğrulandı, `audioplayers_platform_interface-7.2.0`):

- `respectSilence = false` → *"audio will be played even if the device is in
  silent mode"* — telefon sessizken bile çalıyordu.
- `focus = AudioContextConfigFocus.gain` → *"your application is now the sole
  source of audio"*, Android'de `AndroidAudioFocus.gain` → kullanıcının çalan
  müziğini kesiyordu.

İkisi de istenen davranışın tam tersiydi.

## 3. Yapılan düzeltmeler

- `TabBar` kaydırmalı olmaktan çıkarıldı; sekmeler kısa etiketlere geçti
  (`worship.tabPrayer`, `worship.tabWudu` — tr/en/ar üçünde de tanımlı).
  Uzun açıklayıcı başlıklar sayfa içi başlık olarak korundu; abdest rehberine
  eksik olan başlık eklendi. Hiçbir metin kaybolmadı.
- `FlutterLocalNotificationService.initialize()` eklenti yokluğunu yutuyor
  (depoda `WidgetSnapshotService`'in zaten kullandığı kalıp). Tercihler yerel
  olarak saklanmaya devam eder; yalnızca planlama atlanır.
- Açılış tekbiri artık `mixWithOthers` + `respectSilence: true` ile çalıyor:
  sessiz modda hiç çalmıyor, çalan müziği kesmiyor. Çalma bitince player
  serbest bırakılıyor (çift `dispose` koruması ile).

## 4. Eklenen test

`test/worship_responsive_test.dart` — ibadet merkezi ve kıble ekranı için
320 / 360 / 390 / 430 dp, 1.5 metin ölçeği ve tr/en/ar.

Kritik nokta: test yalnızca "istisna yok" demiyor, **her sekmenin görünür alanda
kaldığını** ölçüyor. Zayıf hali sekme ekran dışındayken de geçiyordu.

## 5. Doğrulama sonuçları

Flutter 3.47.1 / Dart 3.13.1 ile:

| Adım | Sonuç |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 60 dosya, **0 değişiklik** |
| `flutter analyze` | **No issues found** |
| `flutter test` | **82/82 geçti** (70 mevcut + 12 yeni) |

## 6. Cihaz testi — YAPILAMADI

Bu oturum **Linux konteynerde** çalışıyor. Gerçek cihaz doğrulaması
yapılmamıştır ve yapılmış gibi raporlanmamalıdır:

- Fiziksel Android telefon veya iPhone bağlı değil.
- macOS/Xcode yok (`xcodebuild` bulunamadı) → iOS derlemesi imkânsız.
- Konteynerde Android SDK/emülatör yok.
- Manyetometre ve ses donanımı headless ortamda simüle edilemez.

Dolayısıyla şunlar **hâlâ doğrulanmamıştır**: kıble okunun gerçek dönüşü,
pusula kalibrasyonu ve metal etkisi, tekbirin gerçek ses seviyesi, sessiz mod
davranışı ve diğer uygulamalarla ses etkileşimi. Yukarıdaki (c) düzeltmesi
paketin belgelenmiş sözleşmesine dayanır; cihazda ayrıca duyulmalıdır.

## 7. TestFlight — YÜKLENMEDİ

Bu ortamdan yüklenemez (macOS ve imzalama sertifikası yok). Gerçek yol
depodaki `.github/workflows/ios-testflight.yml` (macos-26, `workflow_dispatch`).
Build numarası o workflow içinde App Store Connect'ten okunup bir artırılıyor,
yani elle numara seçmeye gerek yok. Tetiklenmesi kullanıcı onayı ister.

## 8. Açık kalan işler

1. `claude/worship-stabilization` → `codex/worship-guide` diff'i incelenip
   merge edilmeli; `main` hâlâ `8459840`'ta.
2. Gerçek cihaz testleri (madde 6).
3. TestFlight yüklemesi (madde 7).
4. **Namaz rehberi derinleştirme ve yeni başlayanlar rehberi** — rekât rekât
   akış, okunacak sûre/dua adları, Arapça metin + okunuş + anlam. Veri modeli
   hazırlanabilir; **içerik kaynak kararı verilmeden yazılmamalıdır.** Dinî
   metin ezberden üretilmemelidir.
5. **Kuran ekranı** — `/quran` hâlâ `PlaceholderPage`. Kapsam raporu için
   aşağıya bakın.

## 9. Kuran ekranı — kapsam raporu (kod yazılmadı)

Uygulama offline-first olduğu için metin **paketlenmek zorunda**; çalışma anında
API çağrısı kural gereği yasak. Karar verilmesi gerekenler:

- **Arapça metin.** Tanzil.net veya Kral Fahd Kompleksi metinleri yaygın
  kullanılır. Yaklaşık boyut: düz Arapça metin ~1–3 MB. Sûre/ayet indeksiyle
  birlikte JSON olarak paketlenebilir.
- **Türkçe meal — asıl darboğaz.** Diyanet İşleri meali telif korumalıdır;
  uygulamaya gömmek için izin gerekir. İzinsiz gömülmemelidir.
- **Font.** Amiri veya Scheherazade New (SIL OFL) lisans açısından rahattır.
  KFGQPC Uthmanic Hafs'ın kullanım şartları ayrıca incelenmelidir.
- **Ses.** Kıraat kayıtları hem büyük (yüzlerce MB) hem lisanslıdır.
  Offline kuralıyla birlikte ilk sürüm için kapsam dışı bırakılması önerilir.
- **Ekranlar.** Sûre listesi → okuma ekranı (ayet numarası, meal aç/kapa,
  yazı boyutu, kaldığın yer). RTL zaten destekleniyor.

**Bu lisans bilgileri doğrulanmalıdır; kesin hukuki bilgi olarak alınmamalıdır.**
Depo kuralı gereği kaynak veya lisans belirsizse içerik eklenmemelidir.

## 10. Bu oturumda değiştirilen dosyalar

```
lib/features/worship/presentation/worship_hub_page.dart   (TabBar + kısa etiketler)
lib/features/worship/presentation/wudu_guide_view.dart    (sayfa başlığı)
lib/features/notifications/data/flutter_local_notification_service.dart (init koruması)
lib/features/audio/presentation/opening_takbir.dart       (AudioContext + temizlik)
lib/core/localization/app_localizations.dart              (2 anahtar x 3 dil)
test/worship_responsive_test.dart                         (YENİ, 12 test)
HANDOFF.md
```

`ios/`, `android/`, `pubspec.yaml`, tema, kıble hesaplayıcı ve diğer feature
klasörleri bu oturumda **değiştirilmedi**.

## 11. Devralan ajan için zorunlu kural

Push etmeden önce `dart --version` çıktısının **3.13.1** olduğunu doğrula.
Kurulum ve komutlar için `CLAUDE.md`'deki "Kalite kapısı" bölümüne bak.
Dördü de (format, analyze, test) temiz olmadan push etme.
