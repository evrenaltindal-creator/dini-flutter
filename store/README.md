# App Store mağaza sayfası

| Klasör | İçerik |
| --- | --- |
| `metadata/<dil>/` | Açıklama, alt başlık, anahtar kelimeler, tanıtım metni, destek ve gizlilik adresi (fastlane `deliver` biçimi) |
| `metadata/*.txt` | Telif satırı ve kategoriler |
| `metadata/<dil>/marketing_url.txt` | Pazarlama adresi: ewocom.com'daki tanıtım sayfası (kaynağı `docs/ewocom/`) |
| `screenshots/raw/<dil>/` | Kullanıcının kendi iPhone'undan çektiği gerçek ekran görüntüleri (girdi) |
| `screenshots/<dil>/` | App Store görselleri, 1320×2868 — `tool/generate_store_screenshots.py` üretir, elle düzenlenmez |
| `screenshots/watch/` | Apple Watch ekran görüntüleri, saatin kendi çözünürlüğünde, çerçevesiz |

Görselleri yeniden üretmek:

```bash
pip install Pillow
python3 tool/generate_store_screenshots.py
```

Gizlilik politikası ve destek sayfasının kaynağı `docs/privacy/` ve
`docs/support/`'tur. Yayında oldukları yer, GitHub Pages'i zaten açık olan
`vardiox-legal` deposunun `namaz-yolu/` klasörüdür
(`https://evrenaltindal-creator.github.io/vardiox-legal/namaz-yolu/privacy/`).
Sayfa değişirse iki yerde de güncellenir.

## Yükleme

GitHub → Actions → **App Store listing** → Run workflow: derleme numarası
ve "incelemeye gönder" seçilir. İş akışı metinleri ve görselleri yükler,
derlemeyi seçer; onaydan sonra otomatik yayınlamaz (kullanıcı kararı:
"Yayınla"ya kendisi basar).

## API ile yapılanlar ve elle yapılan tek şey

`tool/app_store_connect_setup.py` (iş akışı çalıştırır): fiyat ücretsiz,
bütün ülkeler, yaş sınırı anketi (hepsi "yok"), içerik hakları, inceleme
ekibinin iletişim bilgisi ve notu. Telefon numarası depo herkese açık olduğu
için depoda değil, `APP_REVIEW_PHONE` sırrındadır (ya da App Store
Connect'te elle girilir).

Apple'ın API'ye açmadığı tek şey **Uygulama Gizliliği**: App Store Connect
→ uygulama → Uygulama Gizliliği → "Veri toplamıyoruz" → Yayınla.

## Kurallar

- Açıklamadaki her özellik uygulamada gerçekten olmalı; olmayan bir şeyi
  vaat etmek inceleme reddi sebebidir. Premium bu sürümde yok, metinde de
  geçmez.
- Görsellerde başka uygulamaların simgesi bulunmaz (widget görüntüsünde
  Dock örtülür).
- `store_listing_test.dart` görsel boyutlarını ve Apple'ın karakter
  sınırlarını bekçiler.
