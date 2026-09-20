# Namaz Yolu — web sitesi tanıtım paketi

Bu klasördeki görseller `tool/generate_web_assets.py` ile üretilir; simge de
uygulamanın kendi simgesiyle **aynı kaynaktan** (`tool/generate_app_icon.py`)
gelir, böylece sitedeki logo ile telefondaki simge ayrışmaz. Dosyaları elle
düzenleme; tasarım değişince betiği çalıştır:

```bash
pip install Pillow
python3 tool/generate_app_icon.py     # önce uygulama simgesi
bash tool/capture_promo_shots.sh      # gerçek ekran görüntüleri
python3 tool/generate_web_assets.py   # sonra web paketi
```

Ekran görüntüleri gerçek uygulamadan alınmıştır (widget testinde çizilip
`build/promo_shots/` altına yazılır); montaj ya da maket değildir. Görüntüyü
üreten test `test/promo_shots_test.dart`'tır ve `promo` etiketiyle CI'da
atlanır: görüntü diske yazıldıktan sonra koşucu kapanmıyor (ekranlar pusula
ve ses akışlarını açık bırakıyor) ve `flutter test` asılı kalırdı.
`tool/capture_promo_shots.sh` her ekranı ayrı koşucuda çalıştırıp dosya
düşer düşmez koşucuyu kesiyor.

---

## 1. Dosyalar

| Dosya | Boyut | Nerede kullanılır |
| --- | --- | --- |
| `icons/favicon.ico` | 16–64 | `<link rel="icon">` |
| `icons/icon-16.png` … `icon-1024.png` | 16/32/48/64/180/192/256/512/1024 | favicon, apple-touch-icon, PWA |
| `icons/icon-maskable-512.png` | 512 | PWA `purpose: maskable` (Android simgeyi daireye kırpar) |
| `banner-og.png` | 1200×630 | Open Graph / Twitter kartı |
| `hero.png` | 1600×900 | Sayfa başlığı görseli |
| `ekranlar.png` | — | Üç ekran yan yana |
| `ekranlar/*.png` | 600 genişlik | Tek tek ekran görüntüleri (ana sayfa, kıble, imsakiye, namaz takibi, ibadet rehberi, takvim, tesbih) |

### HTML başlığına

```html
<link rel="icon" href="/icons/favicon.ico" sizes="any">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/icon-32.png">
<link rel="apple-touch-icon" sizes="180x180" href="/icons/icon-180.png">
<link rel="manifest" href="/site.webmanifest">

<meta property="og:title" content="Namaz Yolu">
<meta property="og:description" content="Namaz vakitleri, kıble ve ibadet takibi. Her şey cihazında hesaplanır.">
<meta property="og:image" content="https://SITEN/banner-og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
```

### `site.webmanifest`

```json
{
  "name": "Namaz Yolu",
  "short_name": "Namaz Yolu",
  "theme_color": "#0e2842",
  "background_color": "#0e2842",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

Renkler: koyu lacivert `#0e2842`, koyu yeşil `#0c343c`, altın `#d6b26a`,
krem `#f3ecde`.

---

## 2. Türkçe metin

### Tek cümle (başlık altı)

> Namaz vakitleri, kıble ve ibadet takibi — hepsi cihazının içinde.

### Kısa tanıtım (mağaza / site girişi, ~300 karakter)

> Namaz Yolu; namaz vakitlerini, kıbleyi ve hicri takvimi internet
> bağlantısına ihtiyaç duymadan telefonunda hesaplar. Vakit bildirimleri,
> imsakiye, namaz takibi, tesbih ve Ramazan araçları tek uygulamada. Hesap
> açmak gerekmez, reklam yoktur, konumun cihazından çıkmaz.

### Uzun tanıtım

> **Namaz Yolu**, günlük ibadet düzenini tek bir sade uygulamada toplar.
>
> Namaz vakitleri cihazın içinde hesaplanır: seçtiğin şehrin koordinatları ve
> saat dilimi kullanılır, sonuç için hiçbir sunucuya soru sorulmaz. Uçak
> modunda, dağ evinde, internetin olmadığı her yerde aynı şekilde çalışır.
>
> Kıble oku gerçek (coğrafi) kuzeye göre hizalanır; Android'de pusulanın
> manyetik sapması otomatik olarak düzeltilir, iOS'ta cihazın gerçek kuzey
> okuması kullanılır. Ok hizalandığında ekran bunu açıkça söyler.
>
> Vakit bildirimleri her namaz için ayrı ayrı açılıp kapatılabilir; ezan tonu
> seçilebilir, sessiz bildirim tercih edilebilir. Ramazan'da imsak ve iftar
> hatırlatmaları kendi dakikalarıyla ayarlanır.
>
> İbadet takibi kişiseldir ve cihazda kalır: kıldığın namazları işaretle,
> serini ve 17 haftalık ısı haritanı gör, kaza namazlarını say, teravih
> rekâtlarını bir dokunuşla ekle, oruç günlerini tut. Hiçbiri bir hesaba
> bağlı değildir; istersen tek düğmeyle hepsini silersin.
>
> Arayüz Türkçe, İngilizce ve Arapça'dır; Arapça'da yazı yönü sağdan sola
> döner. Her sayfanın arkasında, günün vaktine ve mevsime göre değişen bir
> cami sahnesi durur; Ramazan gecelerinde minareler arasına mahya asılır.

### Özellikler (madde madde)

- **Namaz vakitleri** — cihazda hesaplanır, internet gerekmez. Diyanet dahil
  altı hesap yöntemi, ikindi için iki mezhep seçeneği, vakit başına dakika
  düzeltmesi.
- **Konum** — cihazdan otomatik ya da paketlenmiş şehir listesinden seçim
  (Türkiye'nin 81 ili dahil). Koordinat hiçbir yere gönderilmez.
- **Kıble** — gerçek kuzeye göre hizalanan pusula oku.
- **Bildirimler** — vakit başına ayrı ayarlar, ses seçenekleri, imsak ve
  iftar hatırlatmaları.
- **İmsakiye** — aylık vakit çizelgesi; paylaşılabilir.
- **Hicri takvim** — tabular hesap, gerekirse ±2 gün kaydırma.
- **Namaz takibi** — seri, ısı haritası, muafiyet günleri, kaza sayacı.
- **Tesbih** — sayaç ve geçmiş.
- **Ramazan** — oruç günlüğü, teravih sayacı, mahya.
- **İbadet rehberi** — namazın kılınışı ve okunan metinler.
- **Ana ekran widget'ı (iOS)** — sıradaki vakit her an gözünün önünde.
- **Üç dil** — Türkçe, İngilizce, Arapça (RTL destekli).

### Gizlilik (site için hazır paragraf)

> Namaz Yolu'nun özel bir sunucusu yoktur. Konumun, namaz takibin, tesbih
> sayacın ve bildirim tercihlerin yalnızca cihazında saklanır; hiçbiri
> internete gönderilmez. Uygulamada reklam ağı, analiz aracı ya da çökme
> raporlama servisi bulunmaz. Dışarıya açılan tek adres, kullanıcının kendi
> isteğiyle tarayıcıda açılan Diyanet soru sayfasıdır; satın alma işlemleri
> (ileride açılırsa) Apple ve Google'ın kendi altyapısı üzerinden yürür.
> Ayarlardaki tek düğme bütün yerel verini siler.

### Fiyat

> Lansman döneminde uygulama tam sürüm olarak ücretsizdir; bütün özellikler
> açıktır ve satın alma gerekmez. İleride bir abonelik açılabilir, o zamana
> kadar ödeme alınmaz.

---

## 3. English

**Tagline:** Prayer times, qibla and worship tracking — all on your device.

**Short:**

> Prayer Path calculates prayer times, the qibla direction and the Hijri date
> on your phone, with no internet connection. Prayer notifications, a monthly
> timetable, worship tracking, tasbih and Ramadan tools in one app. No
> account, no ads, and your location never leaves the device.

**Long:**

> **Prayer Path** keeps the daily rhythm of worship in one quiet app.
>
> Prayer times are computed on the device from the coordinates and time zone
> of the city you choose — no server is asked for the answer, so the app works
> the same in airplane mode or with no signal at all.
>
> The qibla needle is aligned to true north: on Android the compass's magnetic
> declination is corrected automatically, on iOS the device's true heading is
> used. The screen says plainly when the needle is aligned.
>
> Notifications are per prayer, with a choice of tones or a silent alert, plus
> suhoor and iftar reminders during Ramadan.
>
> Tracking stays personal and local: mark the prayers you performed, watch your
> streak and a 17-week heatmap, count missed prayers, add teravih rakats with a
> tap, and keep a fasting log. Nothing is tied to an account, and one button
> deletes all of it.
>
> The interface is Turkish, English and Arabic, with right-to-left layout in
> Arabic. Behind every page stands a mosque scene that follows the time of day,
> and on Ramadan nights a mahya hangs between the minarets.

**Privacy paragraph:**

> Prayer Path has no backend of its own. Your location, tracking history,
> tasbih counter and notification preferences are stored on your device only
> and are never uploaded. There is no ad network, no analytics and no crash
> reporting. The single outbound link is the Diyanet question page, opened in
> your browser at your request; purchases, if they are ever enabled, run
> through Apple's and Google's own infrastructure.

---

## 4. العربية

**سطر التعريف:** مواقيت الصلاة والقبلة ومتابعة العبادة — كلّها داخل جهازك.

**تعريف مختصر:**

> يحسب «طريق الصلاة» مواقيت الصلاة واتجاه القبلة والتاريخ الهجري على جهازك دون
> الحاجة إلى إنترنت. إشعارات المواقيت وجدول الإمساكية ومتابعة الصلوات والتسبيح
> وأدوات رمضان في تطبيق واحد. لا حساب، ولا إعلانات، ولا يغادر موقعك جهازك.

**فقرة الخصوصية:**

> لا يملك التطبيق خادمًا خاصًا به. يبقى موقعك وسجل متابعتك وعدّاد التسبيح
> وتفضيلات الإشعارات على جهازك وحده، ولا تُرسل إلى أي مكان. لا توجد شبكة
> إعلانات ولا تحليلات ولا تقارير أعطال. الرابط الخارجي الوحيد هو صفحة أسئلة
> رئاسة الشؤون الدينية، وتُفتح في المتصفح بطلبك.

---

## 5. Eksik görsel

**Ramazan gecesi (mahya) ekranı bu pakette yok.** Mahyanın yazısı yazı tipi
adı verilmeden çiziliyor; test ortamı böyle metni her harf için dolu bir kutu
olarak basıyor, yani üretilen görüntü yanlış anlatırdı. Siteye mahyalı bir
görsel koyacaksan bu ekranın görüntüsü **gerçek cihazdan** alınmalı (Ramazan
gecesi ya da cihazın tarihini bir Ramazan gecesine alarak).

---

## 6. Metinde ne iddia edilmedi (bilerek)

Siteye kopyalarken bunları eklemeyelim; hiçbiri doğrulanmadı:

- **Mağazada değil.** App Store / Play Store'da yayında olduğu yazılmadı,
  indirme bağlantısı konmadı. Uygulama henüz TestFlight'a bile gitmedi.
- **Gerçek cihazda doğrulanmadı.** Pusula, bildirim sesleri ve widget yalnızca
  testlerde çalıştı; "pil dostu", "kesintisiz bildirim" gibi ölçülmemiş
  iddialar yok.
- **Diyanet onayı yok.** Yalnızca Diyanet'in hesap yöntemi kullanılıyor;
  uygulamanın kendi testi Ankara çizelgesine ±3 dakika yaklaşıyor. "Resmî",
  "onaylı" denmiyor — uygulama içinde de "Uygulama Diyanet değildir ve dini
  hüküm vermez" yazıyor.
- **Kuran ekranı yok.** Meal telifi nedeniyle ertelendi; özellik listesinde
  geçmiyor.
- **Ad müsaitliği kontrol edilmedi.** "Namaz Yolu" adının App Store, Play ve
  TÜRKPATENT'te boş olduğu doğrulanmadı — siteyi yayına almadan önce bunu
  kontrol et.
