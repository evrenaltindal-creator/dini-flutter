import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/worship/data/prayer_voice.dart';
import 'package:dini_flutter/features/worship/domain/guided_prayer.dart';
import 'package:dini_flutter/features/worship/domain/prayer_flow.dart';
import 'package:dini_flutter/features/worship/domain/worship_guide.dart';
import 'package:dini_flutter/features/worship/presentation/guided_prayer_page.dart';
import 'package:dini_flutter/main.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Namaz hocası (kullanıcı isteği: "sabah namazını bir hoca gibi bize
/// kıldırsın; ekranda hareketler, altta dualar, istenirse sesli, hızı
/// ayarlanabilir").
class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _FakeVoice implements PrayerVoice {
  _FakeVoice({this.readiness = VoiceReadiness.natural});

  final VoiceReadiness readiness;
  final spoken = <String>[];
  final speeds = <double>[];
  var stops = 0;

  @override
  Future<VoiceReadiness> prepare() async => readiness;

  @override
  Future<void> speak(String text, {required double speed}) async {
    spoken.add(text);
    speeds.add(speed);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> stop() async => stops++;
}

late final String _citiesJson;

DailyPrayerGuide _guide(Prayer prayer) =>
    dailyPrayerGuides.firstWhere((guide) => guide.prayer == prayer);

void main() {
  setUpAll(() {
    TimezoneService.initialize();
    _citiesJson = File(CityRepository.assetKey).readAsStringSync();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeVoice voice;
  late _MemoryStorage storage;
  late List<bool> awake;

  Future<void> open(
    WidgetTester tester,
    String location, {
    _FakeVoice? withVoice,
    Locale? locale,
  }) async {
    voice = withVoice ?? _FakeVoice();
    storage = _MemoryStorage();
    awake = [];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        // Her açılış yeni bir kapsam: Riverpod aynı kapsamda değişen
        // geçersiz kılmaları yok sayar.
        key: UniqueKey(),
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          cityRepositoryProvider.overrideWithValue(
            CityRepository(loadAsset: (_) async => _citiesJson),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 22, 6)),
          prayerVoiceProvider.overrideWithValue(voice),
          screenAwakeProvider.overrideWithValue((on) async => awake.add(on)),
          if (locale != null) localeProvider.overrideWith((ref) => locale),
        ],
        child: DiniApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  final fajrFard = guidedPrayerSteps(_guide(Prayer.fajr), partIndex: 1);

  testWidgets('niyetle başlar, adım adım ilerler', (tester) async {
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 1));

    expect(
      find.text(
        'Niyet ettim Allah rızası için bugünkü sabah namazının farzını '
        'kılmaya.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ayakta'), findsOneWidget);
    expect(find.text('Adım 1/${fajrFard.length}'), findsOneWidget);

    await tester.tap(find.byTooltip('Sonraki adım'));
    await tester.pumpAndSettle();
    expect(find.text('Tekbir'), findsWidgets);
    expect(find.text('اللَّهُ أَكْبَرُ'), findsOneWidget);
    expect(find.text('Allâhü ekber.'), findsOneWidget);

    await tester.tap(find.byTooltip('Sonraki adım'));
    await tester.pumpAndSettle();
    expect(find.text('Kıyam'), findsOneWidget);
    expect(find.text('Sübhâneke'), findsOneWidget);
    // Aynı adımın ikinci metni aşağıda; kaydırınca görünür.
    await tester.dragUntilVisible(
      find.text('Eûzü-Besmele'),
      find.text('Sübhâneke'),
      const Offset(0, -120),
    );
    expect(find.text('Eûzü-Besmele'), findsOneWidget);

    await tester.tap(find.byTooltip('Önceki adım'));
    await tester.pumpAndSettle();
    expect(find.text('Tekbir'), findsWidgets);
  });

  testWidgets('başlatınca adımlar süresi dolunca kendiliğinden geçer', (
    tester,
  ) async {
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 1));
    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    await tester.pump();

    final first = guidedStepDuration(fajrFard[0]);
    await tester.pump(first - const Duration(milliseconds: 100));
    expect(find.text('Adım 1/${fajrFard.length}'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Adım 2/${fajrFard.length}'), findsOneWidget);

    // Duraklatınca durur.
    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Adım 2/${fajrFard.length}'), findsOneWidget);
  });

  testWidgets('hız iki katına çıkınca adım yarı sürede geçer ve saklanır', (
    tester,
  ) async {
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 1));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Hızlandır'));
      await tester.pump();
    }
    expect(find.text('2×'), findsOneWidget);
    expect(storage.values['dini.hoca.speed'], '2.0');

    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    await tester.pump();
    final fast = guidedStepDuration(fajrFard[0], speed: 2);
    expect(fast * 2, guidedStepDuration(fajrFard[0]));
    await tester.pump(fast + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Adım 2/${fajrFard.length}'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Yavaşlat'));
      await tester.pump();
    }
    expect(find.text('0,5×'), findsOneWidget);
  });

  testWidgets('sesli okuma: Arapça metinler sırayla, tesbih üç kez', (
    tester,
  ) async {
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 1));
    await tester.tap(find.byTooltip('Sesli oku'));
    await tester.pumpAndSettle();
    expect(storage.values['dini.hoca.voice'], 'true');
    expect(find.textContaining('yapay konuşma sesiyle'), findsOneWidget);

    // Rükû adımına git ve başlat.
    final bow = fajrFard.indexWhere((s) => s.posture == PrayerPosture.bowing);
    for (var i = 0; i < bow; i++) {
      await tester.tap(find.byTooltip('Sonraki adım'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Rükû'), findsOneWidget);
    voice.spoken.clear();
    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(voice.spoken.take(4), [
      recitationLibrary[RecitationId.tekbir]!.arabic,
      recitationLibrary[RecitationId.rukuTesbih]!.arabic,
      recitationLibrary[RecitationId.rukuTesbih]!.arabic,
      recitationLibrary[RecitationId.rukuTesbih]!.arabic,
    ]);
    // Okuma bittikten kısa bir soluk sonra doğrulmaya geçmiş ve onu okuyor.
    expect(find.text('Adım ${bow + 2}/${fajrFard.length}'), findsOneWidget);
    expect(voice.spoken[4], recitationLibrary[RecitationId.semiallahu]!.arabic);
    expect(voice.speeds.toSet(), {1.0});
  });

  testWidgets('telefonda Arapça ses yoksa söylenir, adımlar yine ilerler', (
    tester,
  ) async {
    await open(
      tester,
      GuidedPrayerPage.routeFor(Prayer.fajr, part: 1),
      withVoice: _FakeVoice(readiness: VoiceReadiness.unavailable),
    );
    await tester.tap(find.byTooltip('Sesli oku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Arapça konuşma sesi bulunamadı'), findsOne);

    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    await tester.pump();
    await tester.pump(guidedStepDuration(fajrFard[0]));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Adım 2/${fajrFard.length}'), findsOneWidget);
    expect(voice.spoken, isEmpty);
  });

  testWidgets('yalnızca temel ses varsa daha iyisinin yeri söylenir', (
    tester,
  ) async {
    await open(
      tester,
      GuidedPrayerPage.routeFor(Prayer.fajr, part: 1),
      withVoice: _FakeVoice(readiness: VoiceReadiness.basic),
    );
    await tester.tap(find.byTooltip('Sesli oku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ses verilerini yükle'), findsOneWidget);
    expect(find.textContaining('yapay konuşma sesiyle'), findsOneWidget);

    // İyi ses varken bu öneri gösterilmez.
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 1));
    await tester.tap(find.byTooltip('Sesli oku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ses verilerini yükle'), findsNothing);
  });

  testWidgets('ekran açık kalır, sayfa kapanınca bırakılır', (tester) async {
    await open(tester, '/guide/prayer/fajr');
    expect(awake, isEmpty);
    await tester.tap(find.text('Hocayla adım adım kıl'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedPrayerPage), findsOneWidget);
    expect(awake, [true]);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(awake, [true, false]);
  });

  testWidgets('son selâmdan sonra namaz tamamlanır', (tester) async {
    await open(tester, GuidedPrayerPage.routeFor(Prayer.fajr, part: 0));
    final steps = guidedPrayerSteps(_guide(Prayer.fajr), partIndex: 0);
    for (var i = 0; i < steps.length - 1; i++) {
      await tester.tap(find.byTooltip('Sonraki adım'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Sola selâm'), findsOneWidget);

    await tester.tap(find.byKey(GuidedPrayerPage.playKey));
    await tester.pump();
    await tester.pump(guidedStepDuration(steps.last));
    await tester.pumpAndSettle();
    expect(find.text('Namaz tamamlandı. Allah kabul etsin.'), findsWidgets);
    await tester.tap(find.text('Baştan başla'));
    await tester.pump();
    expect(find.text('Adım 1/${steps.length}'), findsOneWidget);
  });

  testWidgets('rehberdeki bölüm düğmesi yalnız o bölümü açar', (tester) async {
    await open(tester, '/guide/prayer/isha');
    await tester.scrollUntilVisible(
      find.byTooltip('Vitir vacip bölümünü hocayla kıl'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Vitir vacip bölümünü hocayla kıl'));
    await tester.pumpAndSettle();
    final page = tester.widget<GuidedPrayerPage>(find.byType(GuidedPrayerPage));
    expect(page.partIndex, 3);
    expect(find.textContaining('vitir namazını kılmaya'), findsOneWidget);
  });

  testWidgets('en uzun adımlar telefon ekranına sığar (üç dil)', (
    tester,
  ) async {
    for (final code in ['tr', 'en', 'ar']) {
      await open(
        tester,
        GuidedPrayerPage.routeFor(Prayer.isha, part: 3),
        locale: Locale(code),
      );
      final steps = guidedPrayerSteps(_guide(Prayer.isha), partIndex: 3);
      // Kunut en uzun metindir; anlamı da açılır.
      final qunut = steps.indexWhere(
        (s) => s.instructionKey == 'hoca.step.qunut',
      );
      for (var i = 0; i < qunut; i++) {
        await tester.tap(find.byTooltip(_next[code]!));
        await tester.pump();
      }
      await tester.tap(find.text(_showMeaning[code]!));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: code);
      expect(
        find.text(recitationLibrary[RecitationId.kunut]!.arabic),
        findsOneWidget,
      );
    }
  });
}

const _next = {'tr': 'Sonraki adım', 'en': 'Next step', 'ar': 'الخطوة التالية'};
const _showMeaning = {
  'tr': 'Anlamını göster',
  'en': 'Show meaning',
  'ar': 'إظهار المعنى',
};
