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
