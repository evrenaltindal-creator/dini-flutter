# HANDOFF — Neler yaptık, nerede kaldık

Son güncelleme: 2026-09-20 · Oturum: Claude Code (remote, Linux konteyner)
Branch: `claude/location` (`7fb22d3`) · Taban: `origin/main` (17 commit önde)
Aynı commit `claude/upbeat-gates-1t7ls6` dalına da itildi.

Kapı: `dart format` temiz (Dart 3.13.1), `flutter analyze` sıfır sorun,
**41 dosyada 496 test geçiyor**.

---

## 1. Bu oturumda yazılanlar

| İş | Yer | Not |
| --- | --- | --- |
| İlk açılış akışı + pil rehberi | `features/onboarding/` | Dil → konum → bildirim → pil |
| Mahya | `features/ramadan/domain/mahya*.dart` | Ramazan geceleri, haftalık değişir |
| Oruç takibi | `features/ramadan/.../fasting*` | Hicri yıl+gün anahtarı |
| Teravih sayacı | `features/ramadan/.../teravih*` | Bir dokunuş = bir selam |
| Seri + ısı haritası | `features/tracker/domain/streak.dart` | 17 hafta |
| Muafiyet modu | `features/tracker/data/exemption_repository.dart` | Seriyi taşır, seriye eklemez |
| Kaza takibi | `features/tracker/.../qada*` | Gün gün toplu ekleme |
| Canlı etkinlik (iOS) | `features/widgets/.../live_activity*` | **Swift derlenmedi** |
| Kilit ekranı widget boyutları | `ios/DiniWidget/DiniWidget.swift` | **Swift derlenmedi** |
| Uygulamanın adı: **Namaz Yolu** | `appTitle` (3 dil), iOS/Android görünen ad | en: Prayer Path, ar: طريق الصلاة |
| Yeni simge | `assets/branding/app_icon_source.png` + `tool/generate_app_icon.py` | Verilen tasarımdan üretiliyor |

## 2. Yol boyunca bulunan üç gerçek hata

1. **Vakitler cihazın gününe göre hesaplanıyordu.** Motor kendisine verilen
   tarihin gün/ay/yıl alanlarını olduğu gibi kullanıyor, sağlayıcı ise ham
   cihaz saatini geçiyordu; cihazın dilimi seçilen şehirden farklıyken gece
   yarısı civarında bütün vakitler bir gün kayıyordu. Şehir seçimi
   eklendiğinden beri açıktı. (`0bd3474`)
2. **Yedi sayfa arkadaki camiyi örtüyordu.** Rotayı `MosqueBackdrop` ile
   sarmalamak yetmiyor; temanın zemin rengi opak ve sayfanın kendi düz
   `Scaffold`'u sahneyi boyuyordu. `backdrop_coverage_test.dart` artık bütün
   rotaları dolaşıp bekçilik ediyor. (`3ad0830`)
3. **Ana ekran widget'ı kurulduğu günden beri boştu.** Uygulama yalnızca
   `refresh()` çağırıyordu; `update(snapshot)` hiçbir yerden çağrılmıyordu, yani
   uzantının okuyacağı değerler hiç yazılmamıştı. (`2293279`)

## 3. Çalışma biçimi

Her düzeltmeden sonra hata kasıtlı olarak geri kondu ve **testin düştüğü
görüldü**, sonra onarıldı. Bu oturumda 19 sabotaj denendi; **ikisi ilk
denemede yakalanmadı** ve testler güçlendirildi:

- Ramazan'ın gün sayısını sabit 30 yapmak (tabular takvimde zaten hep 30;
  sahte takvimle 29 günlük Ramazan üretildi).
- Isı haritasında gelecek günleri sıfır gibi çizmek (testteki "bugün" pazara
  denk geldiği için kontrol boşa düşüyordu; hafta ortasına alındı).

## 4. Nerede kaldık — sıradaki elin SENİN olması gerekiyor

Yol haritasında tek başıma ilerleyebileceğim iş kalmadı:

- **Derlenmemiş native değişiklikler:** `MainActivity.kt` (`dini/geomagnetic`),
  `PrayerLiveActivity.swift` + `LiveActivityBridge.swift` (Xcode hedeflerine
  eklenmeli; `project.pbxproj` bilinçli olarak değiştirilmedi), kilit ekranı
  widget boyutları.
- **Gerçek cihazda hiçbir şey doğrulanmadı:** pusula, sessiz moddaki ses,
  bildirimlerin gerçekten çalması, mahyanın okunaklılığı (testteki yazı tipi
  her harfi dolu kutu çiziyor), widget ve kilit ekranı.
- **`claude/location` main'e girmedi**, TestFlight'a build gönderilmedi.
- **Karar bekleyenler:** AR kıble (kamera izni gizlilik duruşunu zayıflatıyor —
  `ROADMAP.md` bunu gereklilik değil gösteriş sayıyor), Apple Watch / Wear OS
  (yeni native hedefler), Kuran ekranı (meal telifi).
- **Simge küçük boyutta detaysız.** 40 pikselde ince altın halkalar birbirine
  giriyor; ≤76 px için %14 kırpma uygulandı ama bu tam çözüm değil. Küçük
  boyutlar için sadeleştirilmiş bir kaynak tasarım gerekir
  (`SMALL_SIZE_LIMIT` o eşiği zaten ayırıyor).
- **Adın müsaitliği doğrulanmadı:** App Store, Play ve TÜRKPATENT kontrolü
  kullanıcıya ait; bu ortamdan erişilemiyor. Ayrıca ilk simge taslağında
  "Huzur Rehberi" de geçiyordu; mağaza alt başlığı olarak kullanılıp
  kullanılmayacağı açık.

Ayrıntılar ve gerekçeler için `ROADMAP.md`, çalışma kuralları için `CLAUDE.md`.
