# ROADMAP — Dini Flutter

Bu dosya ileriye bakar: ne yapılacak, hangi sırayla ve **neden**.
Geçmiş için `todo.md`, oturum devri için `HANDOFF.md`, çalışma kuralları için
`CLAUDE.md`, mimari için `ARCHITECTURE.md`.

Sıralama bir tercih değil, bir bağımlılık zinciridir. Alt sıradaki bir işi üste
almak, üsttekinin yanlış çalışmasına yol açar — gerekçeler her maddede yazılı.

---

## 0. Ölçülmüş durum

Aşağıdakiler iddia değil, kodda ya da testte doğrulanmış olgulardır.

| Konu | Durum | Kanıt |
| --- | --- | --- |
| Vakit hesabı | Cihazda, astronomik | `LocalPrayerTimesCalculator`, `adhan_dart` |
| Diyanet uyumu | Ankara tablosuna ±3 dk | `diyanet_reference_test.dart` |
| Çevrimdışı | Sınırsız: her tarih, her konum | Tablo indirilmiyor, hesaplanıyor |
| Gizlilik | Backend/analytics/reklam yok | `CLAUDE.md` 1. ve 2. kural |
| Yeniden başlatma | Alarmlar yeniden kuruluyor | `ScheduledNotificationBootReceiver`, `BOOT_COMPLETED` + `TIME_SET` + `TIMEZONE_CHANGED` |
| Kıble | Gerçek (coğrafi) kuzeye göre | `CompassNorth`, Android'de `GeomagneticField` düzeltmesi |
| Diller | tr/en/ar tam parite, RTL | `localization_test.dart` |
| Bildirim sesi | Ses başına ayrı Android kanalı | `androidChannelFor` |
| Konum | **Hiçbir yerden ayarlanamıyor** | `LocationService` yazılmış, hiç çağrılmıyor |
| Tam zamanlı alarm izni | **Yok** | Manifest'te `SCHEDULE_EXACT_ALARM` bildirilmemiş |

---

## 1. Faz 0 — "Doğru saatte, doğru yerde" (yayına çıkmadan zorunlu)

Bu fazın tamamı tek bir soruya bakar: *vakit girdiğinde telefon doğru şehir
için doğru saatte ötüyor mu?* Arayüz ne kadar iyi olursa olsun bu cevap "hayır"
ise uygulama silinir.

### 1.1 Konum — her şeyin önünde

**Durum:** `DeviceLocationService.automatic()` yazılmış ama uygulamada tek bir
yerden bile çağrılmıyor. Şehir seçici, elle koordinat girişi ve konum izni akışı
yok. Saat dilimi her yerde `'Europe/Istanbul'` olarak sabit.

**Sonuç:** Kullanıcı nerede olursa olsun İstanbul'un vaktini görüyor. Ankara'da
birkaç dakika, Berlin'de saatler yanlış.

**Yapılacak:**
- İzin akışı + otomatik konum (`geolocator` zaten bağımlı).
- Şehir seçici. Çevrimdışı kuralı gereği şehir listesi **pakette** olmalı;
  geocoding API'si eklenmez.
- Koordinattan IANA saat dilimi çözümü — offline bir tablo ister. GPS'i
  bağlayıp saat dilimini sabit bırakmak, Berlin'deki kullanıcıya Berlin
  koordinatlarını İstanbul saatiyle göstermek demektir.

**Neden ilk:** Alarm iznini düzeltsek bile yanlış şehrin ezanını tam zamanında
çalmış oluruz.

### 1.2 Tam zamanlı alarm izni (Android)

**Durum:** `AndroidScheduleMode.exactAllowWhileIdle` kullanıyoruz. Eklentinin
kendi dokümanı bu modun `SCHEDULE_EXACT_ALARM` iznini gerektirdiğini yazıyor.
İzin ne bizim manifestimizde ne de eklentinin manifestinde bildirilmiş.
Eklentinin sunduğu `requestExactAlarmsPermission()` hiç çağrılmıyor.

**Yapılacak:**
- Manifeste `SCHEDULE_EXACT_ALARM` ve `USE_EXACT_ALARM` ekle.
- Planlamadan önce iznin verilip verilmediğini kontrol et; verilmemişse
  kullanıcıya açıkça sor.
- İzin yoksa `inexactAllowWhileIdle` ile planla ve bunu arayüzde söyle —
  sessizce hiç planlamama en kötü seçenek.

**Not:** `POST_NOTIFICATIONS` ve `VIBRATE` sorun değil; eklentinin manifesti
bunları getiriyor, doğrulandı.

### 1.3 Pil optimizasyonu rehberi

**Durum:** Yok.

**Yapılacak:** İlk açılışta (bkz. 1.4) ve Ayarlar'da, kullanıcıyı üretici
ayarlarına yönlendiren bir rehber: otomatik başlatma, pil kısıtlaması yok.
Xiaomi/Samsung gibi agresif pil yönetimi olan cihazlarda alarm gecikmesinin
asıl sebebi budur.

**Uyarı:** Üretici ayar ekranlarının intent'leri cihaza göre değişir ve
belgelenmemiştir. Açılamayan bir ayar ekranı çökmeye değil, anlaşılır bir
yönlendirmeye düşmelidir.

### 1.4 İlk açılış akışı

**Durum:** Yok. Uygulama doğrudan ana ekrana düşüyor; dil, konum ve bildirim
izni hiç sorulmuyor.

**Yapılacak:** Dil → konum → bildirim izni → pil rehberi. Yukarıdaki üç maddenin
doğal taşıyıcısı burasıdır; ayrı ayrı ekranlara dağıtmak yerine tek akışta
toplanır.

### 1.5 Uygulama simgesi ve derleme doğrulaması

- Simge yapıldı (`tool/generate_app_icon.py`), gerçek cihazda görülmedi.
- `MainActivity.kt` içindeki `dini/geomagnetic` kanalı **derlenmedi**; bu
  ortamda Android SDK kurulamıyor. Android Studio'da bir kez açılması gerekir.

---

## 2. Faz 1 — Görünürlük ve alışkanlık

Faz 0 bitmeden buraya geçilmez: kilit ekranında yanlış şehrin sayacını
göstermek, hiç göstermemekten kötüdür.

### 2.1 iOS Live Activities / Dynamic Island

**Durum:** `ios/DiniWidget` gerçek bir WidgetKit uzantısı olarak var.
`ActivityKit` kullanımı sıfır.

**Yapılacak:** Sıradaki vakte kalan süreyi kilit ekranında ve Dynamic Island'da
göstermek. iOS tarafında en görünür farkı bu yaratır.

### 2.2 Streak ve ısı haritası

**Durum:** `PrayerTrackerDay` yalnızca bugünü tutuyor; geçmiş günlere
dokunulamıyor.

**Yapılacak:** Gün bazlı erişim + GitHub benzeri ısı haritası. Repository
altyapısı hazır, ekranı yok.

### 2.3 Muafiyet modu

Hayız ve nifas dönemlerinde serinin bozulmaması. Küçük bir işaretleme ama
sadakat açısından değeri yüksek. Streak'ten sonra gelir çünkü ona bağlıdır.

### 2.4 Kaza takibi

Biriken kaza namazlarının sayımı. 2.2 ile aynı veri modelini paylaşır.

### 2.5 Ramazan
- [x] İftar ve sahur uyarıları, ayarlanabilir süreler, üç dilde metin
- [x] Hicri tarih düzeltmesi (resmî ilan farkını kullanıcı kapatabiliyor)
- [x] Ramazan geri sayımı, gün sayısı, son on gece, bayram
- [x] Aylık imsakiye
- [ ] **Mahya** — minareler arası ışıklı yazı, her gece değişir, yalnızca
      Ramazan gecelerinde yanar. Tek teknik risk: arka plan `BoxFit.cover` ile
      kırpıldığı için minare çapalarının ekrandaki yerini hesaplamak gerekir.
- [ ] Oruç takibi (30 kutu, tutuldu/tutulmadı, sebebi)
- [ ] Teravih sayacı (tesbih sayacının motoru kullanılır)

---

## 3. Faz 2 — Ekosistem

- Apple Watch ve Wear OS için bağımsız çalışan komplikasyonlar.
- Genişletilmiş iOS widget seçenekleri, kilit ekranı sayaçları.
- AR kıble. **Bedeli var:** kamera izni istemek, "hiçbir şey toplamıyoruz"
  duruşunu zayıflatır. 2D pusula zaten doğru çalışıyor; bu bir gereklilik değil
  gösteriş özelliğidir.
- Kuran ekranı. Meal telif nedeniyle bekliyor; telifsiz ve güvenilir bir
  kaynak bulunmadan açılmaz.

---

## 4. Yapmayacaklarımız ve gerekçeleri

**Odak/kilit modu (başka uygulamaların engellenmesi).** iOS'ta Screen Time
(Family Controls) yetkisi gerekiyor; Apple bunu başvuruyla veriyor ve bir namaz
uygulamasına vermesi şüpheli. Android'de erişilebilirlik servisi gerekiyor ve
Google Play bunu sıkı denetliyor. Mağazadan reddedilme riski, özelliğin
değerinden büyük.

**Tam ekran reklam.** Hiçbir koşulda. Gelir modeli ücretsiz + gönüllü destek +
küçük bir premium katman olarak duruyor; `PremiumLaunchPolicy` şu an her şeyi
ücretsiz veriyor ve bu bilinçli bir karardır.

**İndirilen vakit tablosu.** Rakipler bunu yapıyor, biz hesaplıyoruz. Tablo
indirmek çevrimdışı çalışmayı iyileştirmez, sınırlandırır.

---

## 5. Doğrulanmamış iddialar

Dışarıdan gelen pazar raporlarındaki şu bilgiler **kontrol edilmedi** ve olgu
gibi kullanılmamalıdır: pazar büyüklüğü rakamları, rakip uygulamaların indirme
ve gelir sayıları, belirli cihaz modellerindeki gecikme süreleri.

Bunlara göre karar verilecekse önce doğrulanmalıdır. Kodda doğrulanabilen
teknik iddialar (izinler, API gereksinimleri) bölüm 1'de zaten kontrol edildi ve
kanıtlarıyla yazıldı.

---

## 6. Süregelen borç

- `claude/upbeat-gates-1t7ls6` ve `claude/ramadan-reminders` main'e girmedi.
- Gerçek cihazda hiçbir şey doğrulanmadı: pusula, sessiz moddaki ses,
  bildirimlerin gerçekten çalması.
- TestFlight'a build gönderilmedi.
- `MainActivity.kt` değişikliği derlenmedi (bkz. 1.5).
