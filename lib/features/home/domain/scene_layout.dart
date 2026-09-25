import 'dart:math' as math;
import 'dart:ui';

/// Caminin sahne görselindeki yeri (yüksekliğin oranı olarak): üstte minare
/// uçları, altta revaklar ve şadırvan. Görselin tamamı genişliğe yayılır
/// (minareler iki kenara yakındır). Dört sahne görselinde de aynıdır.
const mosqueTop = 0.33;
const mosqueBottom = 0.76;

/// Caminin altında bırakılan pay: alt kenara yapışmasın, sekme çubuğu ve
/// kartlar camiyi tamamen örtmesin.
const _bottomRoom = 0.04;

/// Sahne görselinin ekrandaki yeri.
///
/// Telefonda görsel ekranı doldurur (`BoxFit.cover`) ve üstten hizalanır;
/// cami zaten sığar. Geniş ekranda (iPad, yatay) aynı kural görseli o kadar
/// büyütüyordu ki ekrana yalnızca gökyüzü sığıyor, cami görünmüyordu. Bu
/// yüzden:
///
/// - Cami ekranı doldururken sığıyorsa görsel yine doldurur, ama cami
///   görünecek kadar yukarı kaydırılır.
/// - Sığmıyorsa görsel caminin tamamı sığacak boya küçültülür ve ortalanır;
///   yanlarda kalan boşluğu sahne aynı görselin bulanık hâliyle doldurur.
///
/// Dönen dikdörtgen ekranın dışına taşabilir (kırpılan kısım).
Rect mosqueSceneRect({required Size screen, required Size image}) {
  if (screen.isEmpty || image.isEmpty) return Offset.zero & image;
  final cover = math.max(
    screen.width / image.width,
    screen.height / image.height,
  );
  final fitMosque =
      screen.height *
      (1 - _bottomRoom) /
      ((mosqueBottom - mosqueTop) * image.height);
  final scale = math.min(cover, fitMosque);
  final painted = Size(image.width * scale, image.height * scale);
  final dx = (screen.width - painted.width) / 2;

  // Önce üstten hizalı; caminin altı ekrandan taşıyorsa yukarı kaydır.
  final mosqueEnd = mosqueBottom * painted.height;
  final limit = screen.height * (1 - _bottomRoom);
  var dy = mosqueEnd > limit ? limit - mosqueEnd : 0.0;
  // Görselin altı ekranın altında kalmalı; yoksa altta boşluk açılır.
  dy = math.max(dy, screen.height - painted.height);
  return Rect.fromLTWH(dx, dy, painted.width, painted.height);
}

/// Görsel ekranın iki yanını doldurmuyor mu (bulanık dolgu gerekir mi)?
bool mosqueSceneNeedsSideFill({required Size screen, required Size image}) {
  final rect = mosqueSceneRect(screen: screen, image: image);
  return rect.left > 0.5;
}
