import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yazılan her Swift dosyası Xcode hedefine de eklenmiş olmalı.
///
/// `AppDelegate.swift` `LiveActivityBridge.register(...)` çağırıyordu ama
/// `LiveActivityBridge.swift` `project.pbxproj` içinde hiçbir derleme
/// aşamasında geçmiyordu: Runner hedefi "Cannot find 'LiveActivityBridge'
/// in scope" ile DERLENMİYORDU. Depoda iOS derlemesi yapılamadığı için bunu
/// hiçbir test yakalamıyordu; dosyanın hedefe girip girmediği ise metin
/// olarak doğrulanabilir.
void main() {
  late String project;

  setUpAll(() {
    project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  });

  /// Dosya gerçekten bir "Sources" aşamasında mı?
  ///
  /// Tek bir "... in Sources" geçişi YETMEZ: `PBXBuildFile` tanımının
  /// kendisi de böyle yazılır. Dosya bir hedefte derleniyorsa aynı metin
  /// hem tanımda hem de aşamanın dosya listesinde geçer, yani en az iki kez.
  bool isCompiled(String project, String fileName) =>
      '$fileName in Sources'.allMatches(project).length >= 2;

  for (final folder in ['ios/Runner', 'ios/DiniWidget']) {
    test('$folder altındaki Swift dosyaları bir hedefte derleniyor', () {
      final files = Directory(folder)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.swift'))
          .toList();
      expect(files, isNotEmpty, reason: '$folder içinde Swift dosyası yok.');

      for (final name in files) {
        expect(
          isCompiled(project, name),
          isTrue,
          reason:
              '$name hiçbir Xcode hedefinde derlenmiyor. Ona başvuran kod '
              '(AppDelegate ya da widget paketi) derlenmez; uygulama hiç '
              'kurulamaz.',
        );
      }
    });
  }

  test('canlı etkinlik türü İKİ hedefte de derleniyor', () {
    // `PrayerActivityAttributes` yalnızca uzantıda tanımlıyken uygulama
    // "Cannot find 'PrayerActivityAttributes' in scope" ile derlenmedi
    // (TestFlight koşusu #9). ActivityKit iki tarafın aynı türü
    // kullanmasını ister: dosya iki Sources aşamasında da olmalı, yani
    // iki tanım + iki liste girdisi = en az dört geçiş.
    expect(
      'PrayerActivityAttributes.swift in Sources'.allMatches(project).length,
      greaterThanOrEqualTo(4),
      reason:
          'Öznitelik dosyası uygulama ve uzantı hedeflerinin ikisinde '
          'de derlenmiyor.',
    );
  });

  test('iOS 16 türleri uygulamanın en düşük sürümünde derlenebilir', () {
    // Uygulama hedefinin en düşük sürümü 15.0; `ActivityAttributes` 16.1
    // ile geldi. Sürüm koşulu olmadan uygulama hedefi derlenmez.
    final files = [
      ...Directory('ios/Runner').listSync(),
      ...Directory('ios/DiniWidget').listSync(),
    ].whereType<File>().where((file) => file.path.endsWith('.swift'));
    for (final file in files) {
      final source = file.readAsStringSync();
      final conformance = RegExp(r'struct \w+: ActivityAttributes')
          .firstMatch(source);
      if (conformance == null) continue;
      final before = source.substring(0, conformance.start);
      expect(
        before.trimRight().endsWith('@available(iOS 16.1, *)'),
        isTrue,
        reason: '${file.path}: ActivityAttributes türü sürüm koşulu taşımıyor.',
      );
    }
  });

  test('canlı etkinlik uzantı hedefinde', () {
    // Widget paketine eklenen PrayerLiveActivity uzantı hedefinde
    // derlenmezse widget paketi derlenmez.
    expect(project, contains('PrayerLiveActivity.swift in Sources'));
  });
}
