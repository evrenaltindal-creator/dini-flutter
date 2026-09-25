# App Store mağaza sayfası

| Klasör | İçerik |
| --- | --- |
| `metadata/<dil>/` | Açıklama, alt başlık, anahtar kelimeler, tanıtım metni, destek ve gizlilik adresi (fastlane `deliver` biçimi) |
| `metadata/*.txt` | Telif satırı ve kategoriler |
| `screenshots/raw/<dil>/` | Kullanıcının kendi iPhone'undan çektiği gerçek ekran görüntüleri (girdi) |
| `screenshots/<dil>/` | App Store görselleri, 1320×2868 — `tool/generate_store_screenshots.py` üretir, elle düzenlenmez |
| `screenshots/watch/` | Apple Watch ekran görüntüleri, saatin kendi çözünürlüğünde, çerçevesiz |

Görselleri yeniden üretmek:

```bash
pip install Pillow
python3 tool/generate_store_screenshots.py
```

Gizlilik politikası ve destek sayfası `docs/privacy/` ve `docs/support/`
altındadır; GitHub Pages ile yayınlanır
(`https://evrenaltindal-creator.github.io/dini-flutter/privacy/`).

## Yükleme

GitHub → Actions → **App Store listing** → Run workflow: derleme numarası
ve "incelemeye gönder" seçilir. İş akışı metinleri ve görselleri yükler,
derlemeyi seçer; onaydan sonra otomatik yayınlamaz (kullanıcı kararı:
"Yayınla"ya kendisi basar).

## Anahtarla yapılamayanlar (App Store Connect sitesinden bir kez)

1. **Uygulama Gizliliği** → "Veri toplamıyoruz". Apple bunu API'ye açmıyor.
2. **Yaş Sınırı** anketi: hepsi "Yok" (şiddet, kumar, kullanıcı içeriği vb.).
3. **Fiyatlandırma ve Kullanılabilirlik** → Ücretsiz.
4. **App Review Bilgileri** → ad, soyad, telefon, e-posta. Telefon
   numarası depo herkese açık olduğu için buraya YAZILMAZ.

## Kurallar

- Açıklamadaki her özellik uygulamada gerçekten olmalı; olmayan bir şeyi
  vaat etmek inceleme reddi sebebidir. Premium bu sürümde yok, metinde de
  geçmez.
- Görsellerde başka uygulamaların simgesi bulunmaz (widget görüntüsünde
  Dock örtülür).
- `store_listing_test.dart` görsel boyutlarını ve Apple'ın karakter
  sınırlarını bekçiler.
