# Namaz Yolu — Ramazan 2027 kampanya planı

Son güncelleme: 22 Ekim 2026

## Amaç ve yayın dönemi

Namaz Yolu'nun Ramazan'da gerçekten çalışan özelliklerini, sakin ve güvenilir
bir kullanıcı deneyimiyle anlatan ayrı bir App Store özel ürün sayfası
hazırlanacak. Genel ürün sayfası korunacak; Ramazan kampanyası ayrı bir bağlantı
ve ayrı ölçümle çalışacak.

Diyanet'in 2027 dini günler listesine göre:

- Ramazan başlangıcı: **8 Şubat 2027 Pazartesi**
- Kadir Gecesi: **5 Mart 2027 Cuma**
- Arefe: **8 Mart 2027 Pazartesi**
- Ramazan Bayramı: **9–11 Mart 2027**

Kampanya sayfası için hedef canlıya geçiş tarihi **1 Şubat 2027**'dir. Bu,
Ramazan aramalarının yükseldiği son haftayı kaçırmadan 8 Şubat'a hazır olmamızı
sağlar. Ana kampanya 8 Şubat–8 Mart arasında çalışır; 12 Mart'ta Ramazan özel
bağlantısı devre dışı bırakılır veya genel ürün sayfasına yönlendirilir.

## Kampanya fikri

Ana vaat:

> **Ramazan'ın ritmini huzurla takip et.**

Destek cümlesi:

> İmsakiye, sahur, iftar ve ibadet takibi tek yerde.

Görsel dünya: gün doğumundan iftar sonrasına uzanan sıcak ve gerçekçi bir
Ramazan atmosferi; lacivert, zümrüt ve ölçülü altın ışık. Yapay bir dinî otorite
izlenimi, aşırı süs, okunmayan kaligrafi veya uygulamada bulunmayan özellik
kullanılmaz. Görsellerde gerçek Namaz Yolu arayüzü görünür.

## Üründe gösterilecek gerçek özellikler

- Şehre ve hesaplama ayarına göre aylık imsakiye
- Ayarlanabilir sahur ve iftar hatırlatmaları
- İftara kalan süre ve Ramazan'ın kaçıncı günü
- Oruç günlüğü
- Teravih sayacı
- Ramazan gecelerinde mahya
- Hicri tarih için kullanıcı tarafından yapılabilen ±1 gün düzeltmesi

Uygulama dinî hüküm, fetva, kesin hilal ilanı veya sağlık tavsiyesi veriyormuş
gibi anlatılmayacak. Vakitlerin seçilen konum ve hesaplama yöntemine göre
hesaplandığı açık kalacak.

## Ürün işi — kampanyadan önce

1. **Ramazan Merkezi** ekranı hazırlanacak. İmsakiye, iftar/sahur ayarları,
   oruç günlüğü ve teravih bu ekranda tek bakışta erişilebilir olacak.
2. Ekranın yolu `/ramadan` olacak. iOS 18 ve sonrasında özel ürün sayfasının
   deep link'i bu ekrana açılacak; eski sürümlerde ana sayfa güvenli geri dönüş
   olacak.
3. 8 Şubat 2027, İstanbul örnek verisiyle ekran görüntüsü modu hazırlanacak.
   Test modu üretim verisini veya cihaz saatini değiştirmeyecek.
4. Türkçe, İngilizce ve Arapça metin paritesi mevcut testlerle korunacak.
5. Gerçek iPhone'da bildirim, saat dilimi, konum, sessiz mod, mahya
   okunabilirliği ve geri dönüş akışları doğrulanacak.

## App Store görsel seti

### Dikey ana afiş — 1206 × 2622 px

Sahura yakın mavi saat veya iftar öncesi altın saat atmosferinde, yetişkin bir
kullanıcı Namaz Yolu'nu telefonunda kullanır. Telefon ekranı gerçek uygulama
arayüzüdür. Duygu huzur, hazırlık ve düzen hissidir; sahne gösterişli değil,
samimidir.

Metin:

- `NAMAZ YOLU`
- `Ramazan'ın ritmini huzurla takip et.`
- `İmsakiye, sahur, iftar ve ibadet takibi tek yerde.`
- `Ramazan boyunca yanında.`

### Header — 3840 × 1646 px

Metin:

- `RAMAZAN NAMAZ YOLU İLE YANINDA`
- `İmsakiye • Sahur • İftar • Oruç • Teravih`

Kullanıcı solda, gerçek uygulama ekranlı telefon sağda veya ters yerleşimde;
metin güvenli alanda ve küçük ekranda da okunabilir olacak.

### Search Results — 1920 × 1280 px

Metin:

- `Ramazan'ı huzurla takip et.`
- `İmsakiye • İftar • Sahur`

Tek bakışta anlaşılacak; küçük metin, uzun açıklama ve gereksiz dekor olmaz.

### App Store ekran sırası

1. Ramazan ana afişi
2. `İftara ne kadar kaldığını gör`
3. `Sahur ve iftar için hatırlatma kur`
4. `Aylık imsakiyeni yanında taşı`
5. `Oruç günlerini kendin için kaydet`
6. `Teravihlerini gece gece takip et`
7. `Ramazan gecelerinde mahya atmosferi`
8. Genel uygulama özellikleri

Her özellik gerçek uygulama ekranıyla gösterilecek. Üretken yapay zekâ yalnızca
yaşam tarzı sahnesi ve arka plan için kullanılabilir; telefon arayüzü sonradan
gerçek ekran görüntüsüyle yerleştirilir.

## App Store metni ve anahtar kelimeler

Türkçe tanıtım metni, 170 karakter sınırı içinde:

> Ramazan boyunca imsakiye, sahur ve iftar hatırlatmaları, oruç günlüğü ve teravih sayacıyla ibadet düzenini tek yerde takip et.

Ramazan özel sayfasında öncelikli arama niyeti:

- `ramazan`
- `imsakiye`
- `iftar`
- `sahur`

Bu kelimeler Ramazan sayfasına ayrılır. Genel özel ürün sayfası namaz, ezan,
kıble, Kuran, meal, tesbih, hicri takvim, dua, abdest ve kaza gibi yıl boyu
geçerli niyetleri taşır. App Store Connect'te aynı kampanya amacını bölecek
gereksiz kelime çakışması yapılmaz.

## Takvim

| Tarih | Çıktı |
| --- | --- |
| 22–31 Ekim 2026 | Mevcut Ramazan özelliklerinin ürün ve doğruluk denetimi |
| 1–20 Kasım 2026 | Ramazan Merkezi, rota ve deep link altyapısı |
| 21 Kasım–15 Aralık 2026 | Üç dil, erişilebilirlik, bildirim ve saat dilimi testleri |
| 16 Aralık 2026–10 Ocak 2027 | Gerçek cihaz doğrulaması ve son hata düzeltmeleri |
| 11–17 Ocak 2027 | Gerçek ekran görüntüleri ve yaşam tarzı görselleri |
| 18–24 Ocak 2027 | App Store özel ürün sayfası, metinler ve son kontrol |
| 25 Ocak 2027 | Apple incelemesine gönderim |
| 1 Şubat 2027 | Sayfayı ve kampanya bağlantılarını canlıya alma |
| 8 Şubat 2027 | Ramazan ana iletişimini başlatma |
| 5 Mart 2027 | Kadir Gecesi iletişimi; yeni özellik vaadi yok |
| 8 Mart 2027 | Son Ramazan günü ve bayram geçiş mesajı |
| 12 Mart 2027 | Ramazan kampanyasını kapatma, sonuçları raporlama |

Apple inceleme süreleri değişebilir. Apple, başvuruların çoğunu 24 saatten kısa
sürede sonuçlandırdığını söylese de kampanya için en az bir haftalık güvenlik
payı korunur. Özel ürün sayfası uygulama sürümünden bağımsız incelenebilir.

## Yayın kapıları

Kampanya ancak aşağıdakilerin tamamı sağlanırsa gönderilir:

- `dart format --set-exit-if-changed` temiz
- `flutter analyze` temiz
- Tüm testler geçiyor
- Ramazan Merkezi gerçek cihazda açılıyor ve geri dönüşler çalışıyor
- İmsakiye ve bildirimler İstanbul dışında en az iki saat diliminde denendi
- Görsellerdeki bütün UI gerçek ve güncel
- Tanıtım metni 170 karakteri aşmıyor
- Görseller Apple ölçülerinde, RGB ve okunabilir
- Uygulama içinde bulunmayan vaat, fiyat, puan veya dinî otorite iddiası yok
- App Store yüklemesinden sonra varlıklar tek tek geri okunup doğrulandı
- Son `Submit for Review` işlemi kullanıcı onayıyla yapıldı

## Ölçüm

Ramazan özel sayfası genel sayfadan ayrı ölçülür:

- Gösterim ve ürün sayfası görüntüleme
- İlk indirme ve dönüşüm oranı
- Kaynak türü ve ülke/bölge
- Ramazan sayfası ile genel sayfanın dönüşüm farkı
- Varsa Apple Ads kampanyasından gelen indirmeler

App Store Connect, özel ürün sayfası analitiğini en az beş ilk indirmeden sonra
göstermeye başlar. İlk yedi gün sonunda görsel sırası ve mesaj değerlendirilir;
kanıt olmadan kampanya ortasında büyük yaratıcı değişiklik yapılmaz.

## Resmî kaynaklar

- Diyanet 2027 dini günler listesi:
  https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=154
- Apple Custom Product Pages:
  https://developer.apple.com/app-store/custom-product-pages/
- Apple özel ürün sayfası gönderimi:
  https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-a-custom-product-page
- Apple ürün sayfası hazırlama rehberi:
  https://developer.apple.com/app-store/product-page/

