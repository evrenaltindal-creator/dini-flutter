import 'package:geolocator/geolocator.dart';

import '../domain/prayer_engine.dart';

/// Cihazın GPS'inden gelen tek bir konum ölçümü.
///
/// Kullanıcının kayıtlı tercihini temsil eden `LocationPreference` ile
/// karıştırılmamalıdır: bu bir ölçüm, o bir ayardır. İki sınıf bir süre aynı
/// adı taşıdı ve hangisinin nerede kullanıldığı belirsizdi.
class DeviceLocation {
  final String displayName;
  final Coordinates coordinates;
  const DeviceLocation(this.displayName, this.coordinates);
}

abstract class LocationService {
  /// Konumu ölçer. İzin yoksa, servis kapalıysa ya da ölçüm başarısızsa null.
  Future<DeviceLocation?> automatic();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();
  @override
  Future<DeviceLocation?> automatic() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition();
    return DeviceLocation('Cihaz konumu', Coordinates(p.latitude, p.longitude));
  }

  static bool valid(Coordinates c) =>
      c.latitude >= -90 &&
      c.latitude <= 90 &&
      c.longitude >= -180 &&
      c.longitude <= 180;
}
