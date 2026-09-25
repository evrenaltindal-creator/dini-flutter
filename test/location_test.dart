import 'dart:convert';
import 'dart:io';

import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/data/location_service.dart';
import 'package:dini_flutter/features/prayer_times/domain/city.dart';
import 'package:dini_flutter/features/prayer_times/domain/location_resolver.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_engine.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService implements LocationService {
  final DeviceLocation? reading;
  final Object? error;
  int calls = 0;

  _FakeLocationService({this.reading, this.error});

  @override
  Future<DeviceLocation?> automatic() async {
    calls++;
    if (error != null) throw error!;
    return reading;
  }
}

/// Dosyadan okunan gerçek şehir listesi. Varlık yükleyicisi testte diskten
/// okur; böylece paketlenen veri de doğrulanmış olur.
Future<CityDirectory> _realDirectory() =>
    CityRepository(loadAsset: (key) async => File(key).readAsString()).load();

void main() {
  setUpAll(TimezoneService.initialize);

  group('paketlenen şehir listesi', () {
    late CityDirectory directory;

    setUpAll(() async => directory = await _realDirectory());

    test('Türkiye\'nin 81 ili eksiksiz', () {
      final turkish = directory.cities.where((c) => c.country == 'TR');
      expect(
        turkish,
        hasLength(81),
        reason: 'İl listesi eksik ya da fazla: ${turkish.length}',
      );
    });

    test('her şehrin saat dilimi gerçekten tanımlı', () {
      // Yazım hatası olan bir IANA kimliği vakitleri sessizce varsayılan
      // dilimle hesaplatır; kullanıcı saatlerin neden kaydığını anlayamaz.
      for (final city in directory.cities) {
        expect(
          TimezoneService.isValid(city.timezoneId),
          isTrue,
          reason: '${city.name}: "${city.timezoneId}" tanınmıyor.',
        );
      }
    });

    test('koordinatlar geçerli aralıkta ve şehirler benzersiz', () {
      final seen = <String>{};
      for (final city in directory.cities) {
        expect(city.latitude, inInclusiveRange(-90, 90), reason: city.name);
        expect(city.longitude, inInclusiveRange(-180, 180), reason: city.name);
        expect(
          seen.add('${city.name}|${city.country}'),
          isTrue,
          reason: '${city.name} listede iki kez var.',
        );
      }
    });

    test('Türk illerinin hepsi Türkiye saat diliminde', () {
      for (final city in directory.cities.where((c) => c.country == 'TR')) {
        expect(city.timezoneId, 'Europe/Istanbul', reason: city.name);
      }
    });

    test('bilinen şehirlerin koordinatları doğru yerde', () {
      // Bir ilin koordinatı yanlış girilirse vakitleri dakikalarca sapar.
      // Elle doğrulanabilir birkaç nokta sabitlenir.
      void expectNear(String name, double lat, double lon) {
        final city = directory.cities.firstWhere((c) => c.name == name);
        expect(city.latitude, closeTo(lat, 0.3), reason: '$name enlem');
        expect(city.longitude, closeTo(lon, 0.3), reason: '$name boylam');
      }

      expectNear('Ankara', 39.93, 32.86);
      expectNear('İstanbul', 41.01, 28.98);
      expectNear('Mekke', 21.42, 39.83);
      expectNear('Berlin', 52.52, 13.41);
    });
  });

  group('şehir arama', () {
    late CityDirectory directory;
    setUpAll(() async => directory = await _realDirectory());

    test('Türkçe karaktersiz yazım da bulur', () {
      // Klavyesinde Türkçe harf olmayan biri şehri bulabilmeli.
      for (final pair in [
        ('sanliurfa', 'Şanlıurfa'),
        ('istanbul', 'İstanbul'),
        ('cankiri', 'Çankırı'),
        ('mugla', 'Muğla'),
        ('duzce', 'Düzce'),
      ]) {
        final results = directory.search(pair.$1);
        expect(
          results.map((c) => c.name),
          contains(pair.$2),
          reason: '"${pair.$1}" araması ${pair.$2} bulmalı.',
        );
      }
    });

    test('adın başından eşleşen önce gelir', () {
      // "an" yazınca Ankara'nın Osmaniye'den sonra çıkması kullanışsızdır.
      final results = directory.search('an');
      expect(results, isNotEmpty);
      expect(
        CityDirectory.foldQuery(results.first.name),
        startsWith('an'),
        reason: 'İlk sonuç aranan metinle başlamıyor: ${results.first.name}',
      );
    });

    test('büyük harf ve boşluk aramayı bozmaz', () {
      expect(directory.search('  ANKARA  ').first.name, 'Ankara');
    });

    test('boş arama listeyi verir, sonuç sayısı sınırlı', () {
      expect(directory.search('').length, lessThanOrEqualTo(30));
      expect(directory.search('', limit: 5), hasLength(5));
    });

    test('eşleşme yoksa boş döner', () {
      expect(directory.search('zzzzzz'), isEmpty);
    });
  });

  group('en yakın şehir', () {
    late CityDirectory directory;
    setUpAll(() async => directory = await _realDirectory());

    test('şehrin kendi koordinatı o şehri verir', () {
      for (final name in ['Ankara', 'İzmir', 'Berlin', 'Mekke']) {
        final city = directory.cities.firstWhere((c) => c.name == name);
        expect(directory.nearest(city.coordinates)?.name, name);
      }
    });

    test('yakın bir nokta doğru saat dilimini verir', () {
      // Berlin'in biraz dışı yine Europe/Berlin olmalı; İstanbul dilimi
      // dönerse vakitler bir saat kayar.
      final nearBerlin = directory.nearest(const Coordinates(52.4, 13.2));
      expect(nearBerlin?.timezoneId, 'Europe/Berlin');

      final nearKonya = directory.nearest(const Coordinates(37.9, 32.5));
      expect(nearKonya?.timezoneId, 'Europe/Istanbul');
    });

    test('boş dizin null döner, çökmez', () {
      expect(const CityDirectory([]).nearest(const Coordinates(0, 0)), isNull);
    });
  });

  group('LocationResolver', () {
    late CityDirectory directory;
    setUpAll(() async => directory = await _realDirectory());

    test('ölçüm en yakın şehrin saat dilimiyle kaydedilir', () async {
      // GPS'i bağlayıp saat dilimini sabit bırakmak, Berlin'deki kullanıcıya
      // Berlin koordinatlarını İstanbul saatiyle göstermek demekti.
      final resolver = LocationResolver(
        service: _FakeLocationService(
          reading: const DeviceLocation(
            'Cihaz konumu',
            Coordinates(52.52, 13.41),
          ),
        ),
        directory: directory,
      );

      final result = await resolver.resolveAutomatic();
      expect(result.isResolved, isTrue);
      expect(result.preference!.timezoneId, 'Europe/Berlin');
      expect(result.preference!.latitude, closeTo(52.52, 0.001));
      expect(
        result.preference!.city,
        'Berlin',
        reason: '"Cihaz konumu" yerine en yakın şehrin adı yazılmalı.',
      );
    });

    test('izin verilmezse ayrı bir sonuç döner', () async {
      final resolver = LocationResolver(
        service: _FakeLocationService(),
        directory: directory,
      );
      final result = await resolver.resolveAutomatic();
      expect(result.outcome, LocationOutcome.permissionDenied);
      expect(result.preference, isNull);
    });

    test('eklenti hatası uygulamayı düşürmez', () async {
      final resolver = LocationResolver(
        service: _FakeLocationService(error: MissingPluginException()),
        directory: directory,
      );
      final result = await resolver.resolveAutomatic();
      expect(result.outcome, LocationOutcome.unavailable);
    });

    test('geçersiz koordinat kaydedilmez', () async {
      final resolver = LocationResolver(
        service: _FakeLocationService(
          reading: const DeviceLocation('bozuk', Coordinates(999, 999)),
        ),
        directory: directory,
      );
      expect(
        (await resolver.resolveAutomatic()).outcome,
        LocationOutcome.unavailable,
      );
    });

    test('listeden seçilen şehir kendi dilimini taşır', () {
      final berlin = directory.cities.firstWhere((c) => c.name == 'Berlin');
      final preference = LocationResolver.fromCity(berlin);
      expect(preference.city, 'Berlin');
      expect(preference.timezoneId, 'Europe/Berlin');
      expect(preference.latitude, berlin.latitude);
    });

    test('tanınmayan saat dilimi varsayılana düşer, çökmez', () {
      const broken = City(
        name: 'Hayali',
        country: 'XX',
        latitude: 10,
        longitude: 10,
        timezoneId: 'Mars/Olympus',
      );
      expect(LocationResolver.fromCity(broken).timezoneId, 'Europe/Istanbul');
    });
  });

  group('CityRepository', () {
    test(
      'bozuk varlık boş dizin verir, uygulama açılmaya devam eder',
      () async {
        final directory = await CityRepository(
          loadAsset: (_) async => 'bu json değil',
        ).load();
        expect(directory.cities, isEmpty);
      },
    );

    test('varlık okunamazsa hata sızmaz', () async {
      final directory = await CityRepository(
        loadAsset: (_) async => throw PlatformException(code: 'missing'),
      ).load();
      expect(directory.cities, isEmpty);
    });

    test('liste yalnızca bir kez okunur', () async {
      var loads = 0;
      final repository = CityRepository(
        loadAsset: (_) async {
          loads++;
          return jsonEncode([
            {
              'name': 'Test',
              'country': 'TR',
              'lat': 1.0,
              'lon': 2.0,
              'tz': 'Europe/Istanbul',
            },
          ]);
        },
      );

      await repository.load();
      await repository.load();
      expect(loads, 1, reason: 'Her aramada varlık yeniden çözülmemeli.');
    });

    test('varlık pubspec içinde bildirilmiş', () {
      // Bildirilmezse liste çalışma anında sessizce boş kalır.
      expect(File(CityRepository.assetKey).existsSync(), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/data/'));
    });
  });
}
