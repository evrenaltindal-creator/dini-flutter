import 'dart:math' as math;

import '../../prayer_times/domain/prayer_engine.dart';

class QiblaCalculator {
  static const kaaba = Coordinates(21.4225, 39.8262);
  const QiblaCalculator();
  double bearing(Coordinates from) {
    final lat1 = from.latitude * math.pi / 180,
        lat2 = kaaba.latitude * math.pi / 180,
        dLon = (kaaba.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Signed shortest turn from the device heading to the Qibla bearing.
  /// Positive values turn clockwise/right, negative values left.
  double turnDifference({required double bearing, required double heading}) =>
      ((bearing - heading + 540) % 360) - 180;
}

/// Pusula okunun birikimli dönüşünü tutar.
///
/// [QiblaCalculator.turnDifference] (-180, 180] aralığında bir değer üretir.
/// Kullanıcı kıblenin tam arkasında kaldığı noktadan geçerken bu değer
/// +179'dan -179'a atlar. Ham değeri doğrudan bir dönüş animasyonuna vermek
/// oku iki derece yerine ters yöne neredeyse tam tur döndürür.
///
/// Bu sınıf ardışık iki fark arasındaki **en kısa** açısal yolu biriktirir;
/// böylece ok her zaman kısa taraftan ve akıcı döner.
class QiblaNeedle {
  /// Animasyona verilecek birikimli dönüş (tur cinsinden).
  final double turns;

  /// En son işlenen fark; ilk okumada null.
  final double? lastDifference;

  const QiblaNeedle({this.turns = 0, this.lastDifference});

  /// İki fark arasındaki en kısa açısal delta (derece).
  static double shortestDelta({required double from, required double to}) =>
      ((to - from + 540) % 360) - 180;

  /// Yeni bir fark okunduğunda okun dönüşünü günceller.
  QiblaNeedle update(double difference) {
    final previous = lastDifference;
    if (previous == null) {
      return QiblaNeedle(turns: difference / 360, lastDifference: difference);
    }
    final delta = shortestDelta(from: previous, to: difference);
    return QiblaNeedle(turns: turns + delta / 360, lastDifference: difference);
  }
}
