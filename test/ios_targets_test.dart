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

  for (final folder in [
    'ios/Runner',
    'ios/DiniWidget',
    'ios/DiniWatch',
    'ios/DiniWatchComplications',
  ]) {
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
      ...Directory('ios/DiniWatch').listSync(),
      ...Directory('ios/DiniWatchComplications').listSync(),
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

  group('Apple Watch uygulaması', () {
    test('iPhone uygulamasına gömülü', () {
      // Saat uygulaması ayrı yüklenmez; iPhone uygulamasının içindeki
      // Watch klasöründen gelir. Gömme aşaması ya da bağımlılık yoksa
      // IPA'da saat uygulaması olmaz.
      expect(project, contains('DiniWatch.app in Embed Watch Content'));
      expect(project, contains(r'dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";'));
      expect(project, contains('DINI_W_DEP /* PBXTargetDependency */,'));
    });

    test('paket kimliği iPhone uygulamasının altında', () {
      // App Store saat uygulamasının kimliğinin iPhone uygulamasının
      // kimliğiyle başlamasını ister.
      expect(
        project,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.dini.diniFlutter.watchkitapp;',
        ),
      );
      final plist = File('ios/DiniWatch/Info.plist').readAsStringSync();
      expect(
        RegExp(
          r'<key>WKCompanionAppBundleIdentifier</key>\s*<string>com\.dini\.diniFlutter</string>',
        ).hasMatch(plist),
        isTrue,
      );
      expect(plist, contains('<key>WKApplication</key>'));
    });

    test('sürümü iPhone uygulamasıyla aynı kaynaktan', () {
      // Saat uygulamasının sürümü iPhone uygulamasınınkinden farklıysa App
      // Store yüklemeyi reddeder; ikisi de Flutter'ın sürümünü okumalı.
      final watchConfigs = RegExp(
        r'DINI_W_(DEBUG|RELEASE|PROFILE) /\* \w+ \*/ = \{[^\n]*',
      ).allMatches(project).map((match) => match.group(0)!);
      expect(watchConfigs, hasLength(3));
      for (final config in watchConfigs) {
        // Flutter derlemede CocoaPods'u çalıştırır ve Pods ayarlarını
        // Debug/Release.xcconfig'e ekler; bunlar iPhone çerçevelerine
        // (flutter_compass ...) bağlanır. Saat hedefi onları devralınca
        // watchOS'ta "Framework 'flutter_compass' not found" ile derlenmedi
        // (TestFlight #12). Yalnızca sürüm değişkenlerini taşıyan
        // Generated.xcconfig temel alınır.
        expect(config, contains('Generated.xcconfig'));
        expect(config, isNot(contains('Release.xcconfig')));
        expect(config, isNot(contains('Debug.xcconfig')));
        expect(
          config,
          contains(r'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)"'),
        );
        expect(
          config,
          contains(r'MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)"'),
        );
        expect(config, contains('SDKROOT = watchos;'));
      }
    });

    test('simgesi ve gizlilik bildirimi var', () {
      // Simgesiz saat uygulaması ve gerekçesi bildirilmemiş UserDefaults
      // kullanımı App Store yüklemesinde reddedilir.
      final icon = File(
        'ios/DiniWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png',
      );
      expect(icon.existsSync(), isTrue);
      expect(
        project,
        contains('Assets.xcassets in Resources */, DINI_W_BF_PRIVACY'),
      );
      final privacy = File('ios/DiniWatch/PrivacyInfo.xcprivacy')
          .readAsStringSync();
      expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    });
  });

  group('kadran göstergesi', () {
    const group = 'group.com.dini.diniFlutter';

    test('saat uygulamasının içine gömülü', () {
      // Saat widget uzantısı iPhone uygulamasına değil, saat uygulamasının
      // PlugIns klasörüne girer; bağımlılık yoksa hiç derlenmez.
      expect(
        project,
        contains('DiniWatchComplications.appex in Embed Foundation Extensions'),
      );
      final watchTarget = RegExp(r'DINI_W_TARGET /\* DiniWatch \*/ = \{[^\n]*')
          .firstMatch(project)!
          .group(0)!;
      expect(watchTarget, contains('DINI_C_PHASE_EMBED'));
      expect(watchTarget, contains('DINI_C_DEP'));
    });

    test('kimliği saat uygulamasının altında, sürümü Flutter\'dan', () {
      final configs = RegExp(
        r'DINI_C_(DEBUG|RELEASE|PROFILE) /\* \w+ \*/ = \{[^\n]*',
      ).allMatches(project).map((match) => match.group(0)!);
      expect(configs, hasLength(3));
      for (final config in configs) {
        expect(
          config,
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = '
            'com.dini.diniFlutter.watchkitapp.complications;',
          ),
        );
        expect(config, contains('SDKROOT = watchos;'));
        expect(config, contains('Generated.xcconfig'));
        expect(
          config,
          contains(r'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)"'),
        );
        expect(
          config,
          contains(
            'CODE_SIGN_ENTITLEMENTS = '
            'DiniWatchComplications/DiniWatchComplications.entitlements;',
          ),
        );
      }
      final plist = File('ios/DiniWatchComplications/Info.plist')
          .readAsStringSync();
      expect(plist, contains('com.apple.widgetkit-extension'));
    });

    test('saat ile gösterge aynı App Group\'u kullanır', () {
      // Gösterge ayrı bir süreçtir; saat uygulamasının UserDefaults'unu
      // göremez. İkisi de grupta değilse gösterge hep boş kalır.
      for (final path in [
        'ios/DiniWatch/DiniWatch.entitlements',
        'ios/DiniWatchComplications/DiniWatchComplications.entitlements',
      ]) {
        expect(File(path).readAsStringSync(), contains(group), reason: path);
      }
      expect(
        'CODE_SIGN_ENTITLEMENTS = DiniWatch/DiniWatch.entitlements;'
            .allMatches(project)
            .length,
        3,
      );
      final model = File('ios/DiniWatch/WatchSchedule.swift')
          .readAsStringSync();
      expect(model, contains('static let appGroup = "$group"'));
      // Çizelge iki hedefte de derlenir: tanım + iki liste girdisi.
      expect(
        'WatchSchedule.swift in Sources'.allMatches(project).length,
        greaterThanOrEqualTo(4),
      );
      final store = File('ios/DiniWatch/ScheduleStore.swift')
          .readAsStringSync();
      expect(store, contains('SharedSchedule.save('));
      expect(store, contains('reloadAllTimelines()'));
      final widget = File(
        'ios/DiniWatchComplications/DiniWatchComplications.swift',
      ).readAsStringSync();
      expect(widget, contains('SharedSchedule.load()'));
      // App Group'tan okunan UserDefaults gerekçesi bildirilmeli.
      for (final path in [
        'ios/DiniWatch/PrivacyInfo.xcprivacy',
        'ios/DiniWatchComplications/PrivacyInfo.xcprivacy',
      ]) {
        expect(File(path).readAsStringSync(), contains('1C8F.1'), reason: path);
      }
    });

    test('ters zaman aralığı kurmaz, vakti şehrin diliminde yazar', () {
      final widget = File(
        'ios/DiniWatchComplications/DiniWatchComplications.swift',
      ).readAsStringSync();
      expect(widget, contains('min(entry.date, time)...time'));
      expect(widget, isNot(contains('style: .time')));
      expect(widget, contains('schedule.clock(next.time)'));
      // watchOS 10 kapsayıcı zemin ister; yoksa gösterge hata yazar.
      expect(widget, contains('.containerBackground(for: .widget)'));
    });

    test('TestFlight iş akışı göstergeyi imzalar ve denetler', () {
      final workflow = File('.github/workflows/ios-testflight.yml')
          .readAsStringSync();
      expect(
        workflow,
        contains(
          'DINI_COMPLICATIONS_BUNDLE_ID: '
          'com.dini.diniFlutter.watchkitapp.complications',
        ),
      );
      expect(workflow, contains(r'"$DINI_COMPLICATIONS_BUNDLE_ID" \'));
      expect(workflow, contains('PlugIns/DiniWatchComplications.appex'));
    });
  });

  test('canlı etkinlik uzantı hedefinde', () {
    // Widget paketine eklenen PrayerLiveActivity uzantı hedefinde
    // derlenmezse widget paketi derlenmez.
    expect(project, contains('PrayerLiveActivity.swift in Sources'));
  });
}
