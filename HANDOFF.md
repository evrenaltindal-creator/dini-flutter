# HANDOFF — Neler yaptık, nerede kaldık

Son güncelleme: 2026-09-13 · Oturum: Codex (local)
Branch: `codex/worship-guide` · Ana dal: `main`

Bu dosya, işi devralan ajanın (Codex veya Claude) baştan keşif yapmadan devam
edebilmesi içindir. Kurallar için `CLAUDE.md`, proje haritası için
`ARCHITECTURE.md`.

---

## 1. Şu anki durum — ÖNEMLİ

| Dal | Commit | CI |
| --- | --- | --- |
| `main` | `8459840` | Önceki format ve dil paritesi düzeltmeleri merge edildi |
| `codex/worship-guide` | çalışma dalı | Yerelde tam kapı **YEŞİL**, Android debug APK üretildi |

Yeni ibadet rehberi işi yalnızca `codex/worship-guide` dalındadır; `main`'e
merge edilene kadar yayımlanmış sürüme girmez.

## 2. Tamamlanan işler

### a) Format kapısı hatası çözüldü (asıl tıkanıklık)

`main`'deki `df98749` commit'i CI'da şu hatayla düşüyordu:

```
Changed lib/app/router.dart
Formatted 53 files (1 changed) in 0.29 seconds.
```

Son altı CI koşusundan dördü aynı yerde kırılmıştı.

**Yanlış teşhis:** "Windows ve Linux Dart formatter'ları satırları farklı kırıyor."
Bu doğru değil. Kontrol edildi: `router.dart` içinde CRLF satır yok, tab yok,
sondaki boşluk yok, depoda `.gitattributes` yok.

**Gerçek sebep:** Dart **sürüm** farkı. CI'daki Flutter 3.47.1 → **Dart 3.13.1**.
Yerelde Dart 3.12 kullanılmıştı. İki sürümün satır kırma algoritması farklı.

**Doğrulama yöntemi:** CI ile birebir aynı SDK (Flutter 3.47.1 / Dart 3.13.1)
kuruldu ve hata tahmin edilmeden yeniden üretildi — CI log'undaki satırın aynısı
çıktı. Fark tek satırmış, `lib/app/router.dart` içindeki `PremiumPage` gövdesinde:
Dart 3.12 `body:` argümanını iki satıra bölüyor, 3.13 tek satırda tutuyor.

### b) Üç dil paritesi artık testle korunuyor

`CLAUDE.md` "her metin tr/en/ar için birlikte eklenir" diyordu ama bunu koruyan
hiçbir test yoktu — bir dili unutmak sessizce geçebiliyordu.

- `AppLocalizations.keysFor(String languageCode)` eklendi (`@visibleForTesting`).
- `test/localization_test.dart` içine iki test eklendi:
  - `every language defines exactly the same keys` — tr/en/ar anahtar kümeleri
    birebir aynı olmalı; hata mesajı eksik/fazla anahtarları isim isim yazar.
  - `no language leaves a key empty` — hiçbir dilde boş değer kalmamalı.

Mevcut durum: üç dilde de **155 anahtar**, parite tam.

### c) Dokümantasyon

- **`CLAUDE.md`** — bağlayıcı çalışma kuralları: backend/analytics yasağı, üç dil
  zorunluluğu, RTL koruma, CI'ın tam komutları, git akışı, tuzaklar.
  Formatter sürüm tuzağı ve doğru SDK'yı kurma komutları da buraya yazıldı.
- **`ARCHITECTURE.md`** — projenin tam haritası: katmanlama, rota tablosu, her
  feature modülü, yerelleştirme/RTL mekanizması, iOS App Group + WidgetKit
  köprüsü, test envanteri, iki workflow, gizlilik duruşu, yeni ekran ekleme adımları.

### d) Ana ekran değişikliği incelendi (kod değiştirilmedi)

`df98749`'daki tam ekran cami düzeni doğru uygulanmış:
`Positioned.fill` → `SizedBox.expand` → `Image.asset(fit: BoxFit.cover)`.
Görsel gerçekten kenardan kenara oturuyor; üstteki dört duraklı koyu gradyan
(`0x8C000000` → `0xD9082021`) ve gölgeli beyaz metin okunabilirliği sağlıyor.
Burada düzeltilecek bir şey bulunmadı.

## 3. Doğrulama — gerçekten çalıştırıldı

CI ile birebir aynı toolchain (Flutter 3.47.1 / Dart 3.13.1) ile:

| Adım | Sonuç |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 53 dosya, **0 değişiklik** |
| `flutter analyze` | **No issues found** |
| `flutter test` | **66/66 geçti** (64 mevcut + 2 yeni) |

## 4. Devralan ajan için kritik kural

**Push etmeden önce `dart --version` çıktısının `3.13.1` olduğunu doğrula.**
Başka bir sürümle formatlarsan CI yine kırılır. Doğru SDK'yı kurmak için:

```bash
curl -sSL -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz
tar -xf /tmp/flutter.tar.xz -C /tmp
export PATH="/tmp/flutter/bin:$PATH"
```

Sonra sırasıyla: `flutter pub get` → `dart format .` → `flutter analyze` →
`flutter test`. Dördü de temiz olmadan push etme.

## 5. Açık işler

1. **`codex/worship-guide` incelenip merge edilmeli.**
2. **Kuran ekranı yazılmadı.** `/quran` rotası hâlâ `PlaceholderPage`
   (`lib/app/router.dart:106`), alt menüde sekmesi hazır. Sıradaki büyük iş bu.
   Kapsam netleştirilmeli: sure listesi mi, okuma ekranı mı, ses olacak mı,
   metin nereden gelecek (backend yasağı gereği paketlenmiş olmalı).
3. **İki ajan aynı anda `main`'e yazmamalı.** Aynı dosyanın aynı satırına iki
   düzeltme gelirse çakışma çıkar. İş başlamadan kimin hangi dosyada çalıştığı
   belirlenmeli.

## 6. Önceki Claude oturumunda dokunulmayanlar

`ios/`, `android/`, `.github/workflows/`, `pubspec.yaml`, tema ve diğer feature
klasörleri bu oturumda değiştirilmedi. Değişen dosyalar yalnızca:
`lib/app/router.dart` (tek satır format),
`lib/core/localization/app_localizations.dart` (test erişimcisi),
`test/localization_test.dart`, `CLAUDE.md`, `ARCHITECTURE.md`, `HANDOFF.md`.

## 7. Codex ibadet rehberi turu — 2026-09-13

- Kıble ekranı ham manyetometre hesabından `flutter_compass` cihaz yönüne
  geçirildi. Kıble açısı artık kayıtlı konumdan hesaplanıyor; en kısa sağ/sol
  dönüş, hizalanma ve kalibrasyon açıklaması gösteriliyor.
- Android konum izinleri ve iOS
  `NSLocationAlwaysAndWhenInUseUsageDescription` eklendi. Bu aynı zamanda
  önceki App Store 90683 amaç metni uyarısını kapatır.
- İbadet alt menüsü `Takip / Namaz nasıl kılınır? / Abdest nasıl alınır? /
  Alarmlar` sekmeli rehbere dönüştürüldü. Beş namazın Hanefî/Diyanet temelli
  sünnet-farz-vitir sırası ve ayrıntı ekranları eklendi.
- Namaz ve abdest için iki çevrimdışı görsel rehber
  `assets/guides/` altına, düşük sesli doğal Türkçe açılış tekbiri
  `assets/audio/opening_takbir.mp3` altına eklendi. Ses Ayarlar'dan kapanabilir.
- Beş vakit alarm kartları vakit, aç/kapat ve önceden hatırlatma seçimini aynı
  yerde gösteriyor.
- Takip, alarm, tesbih, gizlilik ve bilgi akışlarındaki geri dönüş sorunu
  `Scaffold/AppBar` düzenleriyle giderildi; metin taşmalarına açık başlıklar
  esnek Material 3 düzenine alındı.
- Türkçe, İngilizce ve Arapça için tüm yeni metinler birlikte eklendi; RTL
  düzenlerinde `EdgeInsetsDirectional` kullanıldı.

Doğrulama (Flutter 3.47.1 / Dart 3.13.1): format 59/59 değişiklik yok,
`flutter analyze` 0 hata, `flutter test` 70/70 geçti. Native Android debug APK
başarıyla üretildi: `build/app/outputs/flutter-apk/app-debug.apk`.
