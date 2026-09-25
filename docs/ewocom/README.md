# ewocom.com — Namaz Yolu sayfası

`https://ewocom.com/namaz-yolu/` sayfasının yeni hâli. Sitenin kaynağı bu
depoda değil; dosyalar sitenin kendi klasör düzeniyle durur, olduğu gibi
kopyalanır:

| Bu depoda | Sitede |
| --- | --- |
| `namaz-yolu/index.html` | `/namaz-yolu/index.html` (eskisinin yerine) |
| `assets/namaz-yolu-ekran-*.jpg` | `/assets/` (yeni dosyalar) |

Sayfa sitenin başlığını, menüsünü, alt bilgisini, `/assets/styles.css` ve
`/assets/site.js` dosyalarını aynen kullanır; yalnızca `<main>` içeriği
değişti ve yalnızca sitede zaten olan sınıflar kullanıldı (kullanıcı:
"sayfa yapısını bozma sakın"). Sitede zaten olan
`namaz-yolu-icon.png` ve `namaz-yolu-hero.png` kullanılmaya devam eder.

Ekran görüntüleri mağaza görsellerinin kaynağı olan gerçek iPhone
görüntüleridir (`store/screenshots/raw/tr/`); widget görüntüsünde Dock
(başka markaların simgeleri) örtülmüştür.

**Ne zaman yüklenir:** "App Store'dan ücretsiz indir" düğmesi
`apps.apple.com/tr/app/id6805668631` adresini açar; bu adres uygulama
yayınlanınca çalışır. Sayfa "Yayınla"ya basıldıktan sonra siteye konur.

Aynı anda sitede güncellenecek iki kısa yer (bu pakette değil, sitenin
kendi sayfaları):

- `/urunler/` ve ana sayfadaki Namaz Yolu kartı: "Geliştiriliyor" →
  "Yayında", "iPhone ve Android" → "iPhone ve Apple Watch" (Android
  sürümü yok).

App Store Connect'te bu sayfa "Pazarlama URL'si" olarak girilir
(`store/metadata/*/marketing_url.txt`).
