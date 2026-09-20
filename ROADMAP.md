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
| Konum | Ayarlar → Konum; otomatik ya da listeden şehir | `LocationPage`, `location_page_test.dart` |
| Tam zamanlı alarm izni | Bildirildi, izin varken `alarmClock` kipi | `exact_alarm_test.dart` |
| İlk açılış | Dil → konum → bildirim → pil rehberi | `onboarding_test.dart` |

---

## 1. Faz 0 — "Doğru saatte, doğru yerde" (yayına çıkmadan zorunlu)

Bu fazın tamamı tek bir soruya bakar: *vakit girdiğinde telefon doğru şehir
için doğru saatte ötüyor mu?* Arayüz ne kadar iyi olursa olsun bu cevap "hayır"
ise uygulama silinir.

### 1.1 Konum — her şeyin önünde ✅

**Yapıldı.** Ayarlar → Konum ekranı: cihazdan otomatik konum ya da paketlenmiş
listeden şehir seçimi (81 il + 83 dünya şehri). Saat dilimi en yakın şehirden
çözülür; GPS'i bağlayıp dilimi sabit bırakmak Berlin'deki kullanıcıya Berlin
koordinatlarını İstanbul saatiyle göstermek olurdu.

Kalan: elle koordinat girişi (uzman kullanıcı için), şehir listesinin
genişletilmesi ve listedeki koordinatların gözden geçirilmesi.

### 1.2 Tam zamanlı alarm izni (Android) ✅

**Yapıldı.** Manifeste `SCHEDULE_EXACT_ALARM` eklendi. İzin açılışta
sorgulanıyor; verilmişse `alarmClock` kipi kullanılıyor
(`AlarmManager.setAlarmClock()` — sistem bunu çalar saat gibi ele alır ve
düşük güç kipinde bile zamanında çalıştırır), verilmemişse
`inexactAllowWhileIdle`. Ayarlar ekranı izin kapalıyken uyarı gösteriyor ve
açma düğmesi sunuyor; izin verilince alarmlar yeni kiple yeniden kuruluyor.

`USE_EXACT_ALARM` **bilerek bildirilmedi**: kullanıcı onayı istemez ama Google
Play politikası gereği yalnızca çekirdek işlevi alarm/takvim olan uygulamalara
açıktır ve incelemede reddedilme riski taşır. Bir test bunun kazara
eklenmesini engelliyor.

**Not:** `POST_NOTIFICATIONS` ve `VIBRATE` sorun değil; eklentinin manifesti
bunları getiriyor, doğrulandı.

### 1.3 Pil optimizasyonu rehberi ✅

**Yapıldı.** Rehber iki yerde duruyor: ilk açılış akışının son adımında
(bkz. 1.4) ve Ayarlar → Bildirimler ekranının altında kalıcı olarak. Metin
otomatik başlatma ve pil kısıtlamasının kaldırılmasını anlatır; düğme
uygulamanın kendi ayar sayfasını açar.

Üretici ayar ekranlarının intent'leri belgelenmemiştir ve cihazdan cihaza
değişir, bu yüzden doğrudan açılmaya çalışılmıyor: her Android sürümünde
bulunan uygulama ayarları sayfası açılıyor (`geolocator` zaten bu köprüyü
sunuyor, yeni eklenti eklenmedi). Sayfa açılamazsa uygulama çökmüyor,
adımların elle izlenebileceğini söyleyen bir metin gösteriyor; bir test bunu
bekçiler.

### 1.4 İlk açılış akışı ✅

**Yapıldı.** Dil → konum → bildirim izni → pil rehberi. Sıra bağımlılık
sırasıdır: dil seçilmeden sonraki adımların metni anlaşılmaz, konum
bilinmeden bildirimin hangi vakitleri haber vereceği belirsizdir.

Seçilen dil anında uygulanır (`onboardingLocaleProvider`), böylece sonraki
adımlar kullanıcının okuduğu dilde görünür. Akış bitince ya da atlanınca bir
bayrak yazılır; `main.dart` bu bayrağı okuyup başlangıç rotasını
`/onboarding` ya da `/` olarak veriyor.

Kalan: akışın Ayarlar'dan yeniden çalıştırılabilmesi (bayrağı sıfırlayan bir
düğme; `OnboardingRepository.reset()` hazır).

### 1.5 Uygulama simgesi ve derleme doğrulaması

- Simge yapıldı (`tool/generate_app_icon.py`), gerçek cihazda görülmedi.
- `MainActivity.kt` içindeki `dini/geomagnetic` kanalı **derlenmedi**; bu
  ortamda Android SDK kurulamıyor. Android Studio'da bir kez açılması gerekir.

---

## 2. Faz 1 — Görünürlük ve alışkanlık

Faz 0 bitmeden buraya geçilmez: kilit ekranında yanlış şehrin sayacını
göstermek, hiç göstermemekten kötüdür.

### 2.1 iOS Live Activities / Dynamic Island — kod yazıldı, DERLENMEDİ

**Dart tarafı bitti ve test edildi.** Kilit ekranında sıradaki vaktin sayacı:

- Etkinlik vakte **bir saat kala** belirir, vakit girdikten **on beş dakika**
  sonra kapanır. Bütün gün duran bir canlı etkinlik kilit ekranını meşgul eder
  ve iOS onu zaten sekiz saatle sınırlar.
- Süren etkinliğin **aynası cihazda saklanır**: etkinlik uygulamadan uzun
  yaşar, uygulama yeniden açıldığında ikinci kez `start` çağrılsaydı kilit
  ekranında iki sayaç birden görünürdü.
- **Metinler Dart tarafında çevrilir.** Uzantının çeviri haritasına erişimi
  yok; vakit adı hazır metin olarak gönderilir.
- Sayaç SwiftUI'da `Text(timerInterval:)` ile işletilir: uygulama her dakika
  güncelleme göndermek zorunda değildir.

**Yapılması gerekenler (bu ortamda yapılamaz, Xcode ister):**

1. `ios/DiniWidget/PrayerLiveActivity.swift` ve
   `ios/Runner/LiveActivityBridge.swift` dosyalarını Xcode'da ilgili
   hedeflere (target) ekleyin — `project.pbxproj` bilinçli olarak
   değiştirilmedi (bkz. `CLAUDE.md` 6. kural).
2. `PrayerActivityAttributes` hem uzantı hem Runner hedefinde görünmeli;
   köprü onu kullanıyor.
3. Gerçek cihazda deneyin: simülatörde Dynamic Island davranışı eksiktir.

Derlenmediği için bu madde **tamamlandı sayılmaz**.

### 2.2 Streak ve ısı haritası ✅

**Yapıldı.** Takip ekranında güncel seri, en uzun seri, tamamlanan gün sayısı
ve son on yedi haftayı gösteren ısı haritası.

Gün ancak **beş vaktin hepsi** işaretlenince tamamlanmış sayılır; daha gevşek
bir ölçü seriyi anlamsız kılardı. **Bugün henüz boşken seri bozulmaz** — gün
bitmeden "seriyi kaybettin" demek, sabah namazından sonra uygulamayı açan
herkese yanlış söylerdi. Isı haritasında gelecek günler boş bırakılır, sıfırla
doldurulmaz: tutulmamış bir gün ile henüz gelmemiş bir gün aynı şey değildir.

### 2.3 Muafiyet modu ✅

**Yapıldı.** Takip ekranında "Bugün namaz kılmıyorum" anahtarı. Muaf işaretli
günler seriyi **bozmaz ve seriye eklenmez**: o günlerde namaz kılınmadığı için
eksik kalan bir şey yoktur. Seri muaf günün üzerinden atlayarak devam eder,
ısı haritasında muaf gün boş günden ayrı renkte görünür.

Uygulama burada bir hüküm vermez; işaret kullanıcının kendi kaydıdır ve
cihazında kalır. Muafiyet ayrı bir anahtar altında saklanır
(`dini.tracker.exempt.<tarih>`), namaz kaydına karışmaz.

### 2.4 Kaza takibi ✅

**Yapıldı.** Vakit başına kaza sayacı (`/qada`, takip ekranından açılır).
Biriken kaza gün ya da yıl olarak hatırlandığı için 1 / 7 / 30 / 365 günlük
hazır ekleme düğmeleri var; beş vakte birden yazar. Kılındıkça tek tek düşer,
sayı sıfırın altına inmez.

**Uygulama kaç kaza borcu olduğunu hesaplamaz.** Sayıyı kullanıcı girer;
ekran, hesabın ve hükmün bir fetva konusu olduğunu söyleyip Diyanet'e
yönlendirir.

### 2.5 Ramazan
- [x] İftar ve sahur uyarıları, ayarlanabilir süreler, üç dilde metin
- [x] Hicri tarih düzeltmesi (resmî ilan farkını kullanıcı kapatabiliyor)
- [x] Ramazan geri sayımı, gün sayısı, son on gece, bayram
- [x] Aylık imsakiye
- [x] **Mahya** — minareler arası ışıklı yazı. Akşamdan imsağa yanar, yazı
      haftada bir değişir; ilk gece, Kadir Gecesi, son gece ve bayram kendi
      yazılarını taşır. Hicri gün akşam başladığı için akşamdan sonraki mahya
      ertesi geceye aittir — Ramazan'dan önceki akşam "hoş geldin" mahyası
      yanar. Minare çapaları görselden ölçüldü (`mahya_geometry.dart`) ve
      `BoxFit.cover` kırpması hesaba katılıyor; minareler ekran dışında
      kalırsa mahya çizilmez. Perdesi koyu ekranlarda mahya söner, çünkü
      içeriğin okunabilirliği önce gelir.
- [x] **Oruç takibi** — Ramazan'ın her günü için kutu; tutuldu / tutulmadı
      (hastalık, yolculuk, âdet-loğusalık, gebelik-emzirme, diğer). Gelecek
      gün işaretlenemez. Kayıt hicri yıl + gün anahtarıyla saklanır, miladi
      tarihle değil: kullanıcı tarih düzeltmesini değiştirdiğinde kayıt
      kaymamalı. Gün sayısı sabit değil sayılır. Uygulama kaza ya da fidye
      hükmü vermez; ekran bunun için Diyanet'e yönlendirir.
- [x] **Teravih sayacı** — gecelik sayaç (bir dokunuş = bir selam = iki rekât),
      seçilebilir hedef (8 / 20, varsayılan 20) ve Ramazan boyunca gece gece
      kayıt. Rekât sayısı bir hüküm değildir; ekran bunu söyleyip Diyanet'e
      yönlendirir. Sayaç hedefte kilitlenmez: camiye göre kılınan rekât değişir.
      Gece, akşam ezanından sonra ertesi güne yazılır.

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
- Arka plan sahnesi yedi sayfada örtülüyordu (kendi Scaffold'ları opaktı);
  düzeltildi ve her rotayı dolaşan bir test eklendi.
- Gerçek cihazda hiçbir şey doğrulanmadı: pusula, sessiz moddaki ses,
  bildirimlerin gerçekten çalması.
- Mahyanın harfleri yalnızca testteki yazı tipiyle görüldü (her harf dolu
  kutu çizilir); okunaklılık cihazda kontrol edilmeli.
- TestFlight'a build gönderilmedi.
- `MainActivity.kt` değişikliği derlenmedi (bkz. 1.5).
- Canlı etkinliğin Swift tarafı derlenmedi ve Xcode hedeflerine eklenmedi
  (bkz. 2.1).
