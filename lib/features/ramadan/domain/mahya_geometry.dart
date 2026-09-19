import 'dart:ui';

/// Mahya kablosunun iki ucu ve yazının sığacağı alan.
class MahyaAnchors {
  /// Sol ve sağ minarenin şerefe hizası.
  final Offset left, right;

  /// Kablonun ortasındaki sarkma noktası.
  final Offset sag;

  const MahyaAnchors({
    required this.left,
    required this.right,
    required this.sag,
  });

  double get width => right.dx - left.dx;
}

/// Minare şerefelerinin **görseldeki** yeri (genişlik/yükseklik oranı olarak).
///
/// Sayılar tahmin değil: `assets/scenes/mosque_night.png` üzerinde minare
/// gövdeleri taranarak ölçüldü. Sol minare 839 pikselin 80'inde, sağ minare
/// 770'inde; üst şerefeler 1874 pikselin 855'inde.
const mahyaLeftAnchor = Offset(0.095, 0.456);
const mahyaRightAnchor = Offset(0.918, 0.456);

/// Kablonun ortadaki sarkması, görsel yüksekliğinin oranı olarak.
const mahyaSagRatio = 0.022;

/// Mahyanın çizilmeye değeceği en küçük genişlik.
///
/// Bunun altında yazı okunmaz bir şeride döner; çizmemek daha iyidir.
const mahyaMinimumWidth = 180.0;

/// Ekran kenarıyla kablo ucu arasında bırakılan en küçük boşluk.
const mahyaEdgeMargin = 12.0;

/// Arka plan görseli [BoxFit.cover] ile kırpıldığı için minarelerin ekrandaki
/// yeri ekran oranına göre kayar. Bu fonksiyon o dönüşümü yapar.
///
/// Görsel `Alignment.topCenter` ile hizalanır: yatayda ortalanır, dikeyde
/// üstten başlar. Ekran görselden geniş oranlıysa altı kırpılır; dar
/// oranlıysa yanları kırpılır ve minareler ekran dışına çıkabilir. İkinci
/// durumda uçlar kenara çekilir, kalan genişlik [mahyaMinimumWidth] altına
/// düşerse mahya çizilmez (null döner).
MahyaAnchors? mahyaAnchors({required Size screen, required Size image}) {
  if (screen.isEmpty || image.isEmpty) return null;

  final scale = (screen.width / image.width) > (screen.height / image.height)
      ? screen.width / image.width
      : screen.height / image.height;
  final painted = Size(image.width * scale, image.height * scale);
  final dx = (screen.width - painted.width) / 2;

  double x(double fraction) => dx + fraction * painted.width;
  double y(double fraction) => fraction * painted.height;

  final top = y(mahyaLeftAnchor.dy);
  // Şerefe ekranın altında kalıyorsa (çok kısa pencere) mahya görünmez.
  if (top < 0 || top > screen.height) return null;

  final leftX = x(mahyaLeftAnchor.dx).clamp(mahyaEdgeMargin, screen.width);
  final rightX = x(mahyaRightAnchor.dx)
      .clamp(0.0, screen.width - mahyaEdgeMargin);
  if (rightX - leftX < mahyaMinimumWidth) return null;

  return MahyaAnchors(
    left: Offset(leftX, top),
    right: Offset(rightX, y(mahyaRightAnchor.dy)),
    sag: Offset((leftX + rightX) / 2, top + painted.height * mahyaSagRatio * 2),
  );
}
