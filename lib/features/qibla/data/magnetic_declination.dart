import 'dart:io';

import 'package:flutter/services.dart';

import '../../prayer_times/domain/prayer_engine.dart';
import '../domain/compass_north.dart';

/// Yerel manyetik sapmayı işletim sisteminden sorar.
///
/// Android'in `GeomagneticField` sınıfı Dünya Manyetik Modeli'ni cihazda
/// taşır; ağ gerekmez, uygulamanın çevrimdışı kuralı korunur. iOS'ta
/// `CLHeading.trueHeading` zaten gerçek kuzeye göre geldiği için sapmaya
/// ihtiyaç yoktur.
///
/// Modeli burada yeniden yazmıyoruz: katsayıları ezberden yazmak, kıbleyi
/// sessizce yanlış gösterme riski taşır.
class MagneticDeclinationService {
  static const channel = MethodChannel('dini/geomagnetic');

  /// Platformdan sapmayı okuyan işlev. Testlerde değiştirilir.
  final Future<double?> Function(Coordinates where) read;

  /// Cihazın verdiği yönün gerçek kuzeye göre olup olmadığı.
  final bool readingIsTrueNorth;

  MagneticDeclinationService({
    Future<double?> Function(Coordinates where)? read,
    bool? readingIsTrueNorth,
  }) : read = read ?? _fromPlatform,
       readingIsTrueNorth = readingIsTrueNorth ?? Platform.isIOS;

  /// [where] için pusula düzeltmesini çözer.
  ///
  /// Sapma okunamazsa düzeltmesiz bir sonuç döner ve [CompassNorth.isKnown]
  /// false olur; ok yine çizilir, ama arayüz belirsizliği söyleyebilir.
  Future<CompassNorth> resolve(Coordinates where) async {
    if (readingIsTrueNorth) {
      return const CompassNorth(readingIsTrueNorth: true);
    }
    try {
      final declination = await read(where);
      if (declination == null) {
        return const CompassNorth(readingIsTrueNorth: false);
      }
      return CompassNorth(declination: declination, readingIsTrueNorth: false);
    } catch (_) {
      return const CompassNorth(readingIsTrueNorth: false);
    }
  }

  static Future<double?> _fromPlatform(Coordinates where) =>
      channel.invokeMethod<double>('declination', {
        'latitude': where.latitude,
        'longitude': where.longitude,
      });
}
