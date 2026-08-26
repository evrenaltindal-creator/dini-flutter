# Step 3 — Dynamic Mosque Experience

Dini’nin ana ekranı artık cihaz üzerinde hesaplanan namaz vakitlerinden deterministic bir `MosqueSceneState` üretir. Fajr, sunrise, Dhuhr, Asr, golden hour, Maghrib ve Isha sınırları sahnenin atmosferini, güneş/ay görünürlüğünü, yıldız yoğunluğunu ve cami pencere aydınlatmasını değiştirir. Render katmanı Flutter `CustomPainter` kullanır; ağ, backend veya uzaktan görsel bağımlılığı yoktur.

Günün içeriği `OfflineContentRepository` içindeki küçük, kaynak metadatası bulunan ayet, hadis ve dua seed’lerinden seçilir. Aynı tarih her zaman aynı içerik kimliğini verir. Kart; genişletme/daraltma, kopyalama, sistem paylaşım ekranı ve favorileme etkileşimlerini sunar. Favoriler `LocalStorage` abstraction üzerinden SharedPreferences’a yazılır; test veya preview override’ı yoksa güvenli null fallback kullanılır.

`IslamicCalendar`, yerel tabular Hicri dönüşümle tarih, Cuma ve Ramazan durumunu üretir. Bu yaklaşım astronomik ay gözlemi veya Diyanet’in bölgesel ilanlarının yerine geçmez; uygulama içinde offline ve deterministik bir gösterim sağlar.

Kalite kapısı: `dart format` başarılıdır, `flutter analyze` “No issues found” döndürmüştür ve tüm 30 test geçmiştir. Android SDK ve Xcode bu Linux sandbox’ında bulunmadığı için native APK/iOS archive doğrulaması yapılmamıştır.
