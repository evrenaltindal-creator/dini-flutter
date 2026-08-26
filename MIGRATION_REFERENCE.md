# Migration Reference

Yeni production foundation `/home/ubuntu/dini_flutter` altında bağımsızdır. Eski `/home/ubuntu/dini_mobile` Expo/React Native projesi silinmemiş ve bu projeye dependency/source olarak karıştırılmamıştır.

## Reusable product concepts

MosqueScene’in dönem bazlı atmosfer fikri, prayer strip, günlük içerik kartları, hızlı eylemler, local-first privacy dili ve beş sekmeli ürün bilgi mimarisi Flutter’da yeniden tasarlanabilir.

## Not directly reusable

Eski `.tsx` ekranları, Expo Router rotaları, NativeWind sınıfları, AsyncStorage adapterı, TypeScript prayer engine’i, Expo notification/location çağrıları ve JSON widget contract’ı Flutter production koduna doğrudan taşınamaz. Bunlar yalnızca davranış ve ürün referansıdır; native Flutter karşılıkları Dart ile yeniden yazılmalıdır.

## Foundation limitation

Bu aşamada prayer calculation, native notifications, native home-screen widgets, StoreKit/Google Play Billing, gerçek religious seed data ve network entegrasyonu intentionally uygulanmamıştır.
