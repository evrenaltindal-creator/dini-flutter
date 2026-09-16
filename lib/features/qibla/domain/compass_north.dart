/// Pusula okumasının hangi kuzeye göre olduğunu ve gerçek kuzeye çevrimini
/// tanımlar.
///
/// Kıble açısı [QiblaCalculator.bearing] ile büyük daire üzerinden hesaplanır
/// ve **gerçek (coğrafi) kuzeye** göredir. Cihazdan gelen yön ise platforma
/// göre değişir:
///
/// * iOS: `CLHeading.trueHeading` — zaten gerçek kuzeye göredir.
/// * Android: `SensorManager.getOrientation` — **manyetik** kuzeye göredir;
///   sapma (declination) uygulanmaz.
///
/// İkisini ayırt etmeden karşılaştırmak, Android'de oku yerel manyetik sapma
/// kadar kaydırır. Türkiye'de bu sapma yaklaşık beş altı derece doğudur, yani
/// kullanıcı kıbleyi sürekli birkaç derece yanlış görür.
class CompassNorth {
  /// Manyetik sapma, derece. Doğuya pozitif — gerçek kuzey, manyetik
  /// kuzeyin bu kadar batısındadır.
  final double declination;

  /// Cihazın verdiği yön zaten gerçek kuzeye göreyse true.
  final bool readingIsTrueNorth;

  const CompassNorth({this.declination = 0, this.readingIsTrueNorth = true});

  /// Sapmanın bilinip bilinmediği. Bilinmiyorsa arayüz bunu söylemelidir;
  /// sessizce sıfır varsaymak kullanıcıyı yanıltır.
  bool get isKnown => readingIsTrueNorth || declination != 0;

  /// Cihaz okumasını gerçek kuzeye çevirir.
  double toTrue(double heading) =>
      normalize(readingIsTrueNorth ? heading : heading + declination);

  /// Gerçek kuzeye göre bir açının manyetik pusuladaki karşılığı.
  ///
  /// Basılı çizelgeler ve bazı resmî kaynaklar kıble açısını manyetik
  /// pusulaya göre yayımlar; kullanıcı iki değeri karşılaştırabilsin diye
  /// gerekir.
  double toMagnetic(double trueBearing) => normalize(trueBearing - declination);

  static double normalize(double degrees) => (degrees % 360 + 360) % 360;
}
