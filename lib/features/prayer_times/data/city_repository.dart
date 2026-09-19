import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/city.dart';

/// Paketlenmiş şehir listesini okur.
///
/// Liste `tool/generate_cities.py` ile üretilir ve uygulamanın içinde gelir;
/// ağdan indirilmez.
class CityRepository {
  static const assetKey = 'assets/data/cities.json';

  final Future<String> Function(String key) loadAsset;

  CityRepository({this.loadAsset = _fromRootBundle});

  CityDirectory? _cached;

  /// Şehir listesini çözer. Varlık okunamazsa boş bir dizin döner; şehir
  /// seçici boş kalır ama uygulama açılmaya devam eder.
  Future<CityDirectory> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final raw = await loadAsset(assetKey);
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(City.fromJson)
          .toList();
      return _cached = CityDirectory(list);
    } catch (_) {
      return _cached = const CityDirectory([]);
    }
  }

  static Future<String> _fromRootBundle(String key) =>
      rootBundle.loadString(key);
}
