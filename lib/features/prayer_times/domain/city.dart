import 'dart:math' as math;

import 'prayer_engine.dart';

/// Paketlenmiş şehir kaydı.
class City {
  final String name;

  /// ISO ülke kodu. Aynı adı taşıyan şehirleri ayırmaya da yarar.
  final String country;
  final double latitude, longitude;

  /// IANA saat dilimi kimliği.
  final String timezoneId;

  const City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezoneId,
  });

  Coordinates get coordinates => Coordinates(latitude, longitude);

  factory City.fromJson(Map<String, dynamic> json) => City(
    name: json['name'] as String,
    country: json['country'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    timezoneId: json['tz'] as String,
  );
}

/// Şehir listesi üzerinde arama ve en yakın şehir çözümü.
///
/// Uygulama çevrimdışıdır; geocoding servisi çağrılamaz. Hem şehir seçici hem
/// de "koordinattan saat dilimi" bu listeye dayanır.
class CityDirectory {
  final List<City> cities;

  const CityDirectory(this.cities);

  /// [query] ile eşleşen şehirler.
  ///
  /// Arama Türkçe karakterlere duyarsızdır: "sanliurfa" yazan biri
  /// "Şanlıurfa"yı bulabilmelidir. Adın başından eşleşenler önce gelir;
  /// "an" yazınca Ankara'nın Osmaniye'den sonra çıkması kullanışsızdır.
  List<City> search(String query, {int limit = 30}) {
    final needle = foldQuery(query);
    if (needle.isEmpty) return cities.take(limit).toList();

    final starts = <City>[];
    final contains = <City>[];
    for (final city in cities) {
      final name = foldQuery(city.name);
      if (name.startsWith(needle)) {
        starts.add(city);
      } else if (name.contains(needle)) {
        contains.add(city);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  /// [where] noktasına en yakın şehir. Liste boşsa null.
  ///
  /// Cihazın GPS'inden gelen koordinatın saat dilimini çözmek için kullanılır.
  /// Tam bir saat dilimi sınır haritası paketlemek yerine en yakın şehrin
  /// dilimi alınır; şehirlerin seyrek olduğu bölgelerde sınıra yakın noktalarda
  /// yanılabilir, bu yüzden kullanıcı sonucu Ayarlar'dan değiştirebilmelidir.
  City? nearest(Coordinates where) {
    if (cities.isEmpty) return null;
    var best = cities.first;
    var bestDistance = double.infinity;
    for (final city in cities) {
      final distance = _distanceKm(where, city.coordinates);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = city;
      }
    }
    return best;
  }

  /// Türkçe ve aksanlı harfleri arama için sadeleştirir.
  ///
  /// `toLowerCase` tek başına yetmez: Türkçe'de 'I' küçüldüğünde 'ı' olur ve
  /// klavyesinde bu harf olmayan biri şehri bulamaz.
  static String foldQuery(String value) {
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'i̇': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
      'é': 'e',
      'è': 'e',
      'ø': 'o',
      'å': 'a',
      'ä': 'a',
      'ë': 'e',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char);
    }
    return buffer.toString().trim();
  }

  /// İki nokta arasındaki büyük daire mesafesi (km).
  static double _distanceKm(Coordinates a, Coordinates b) {
    const earthRadius = 6371.0;
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(a.latitude)) *
            math.cos(_radians(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
