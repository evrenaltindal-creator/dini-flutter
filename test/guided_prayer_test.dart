import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/worship/domain/guided_prayer.dart';
import 'package:dini_flutter/features/worship/domain/prayer_flow.dart';
import 'package:dini_flutter/features/worship/domain/worship_guide.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Namaz hocasının kıldırdığı sıra. Kurallar Diyanet'in Hanefî anlatımıdır
/// (Namaz İlmihali); her test bir kuralı bekçiler.
DailyPrayerGuide _guide(Prayer prayer) =>
    dailyPrayerGuides.firstWhere((guide) => guide.prayer == prayer);

int _partOf(Prayer prayer, PrayerPartKind kind) =>
    _guide(prayer).parts.indexWhere((part) => part.kind == kind);

List<GuidedStep> _steps(Prayer prayer, PrayerPartKind kind) =>
    guidedPrayerSteps(_guide(prayer), partIndex: _partOf(prayer, kind));

/// Bir rekâtın kıyamında okunanlar, sırasıyla.
List<RecitationId> _standingIn(List<GuidedStep> steps, int rakat) => [
  for (final step in steps)
    if (step.rakat == rakat && step.posture == PrayerPosture.standing)
      for (final item in step.recitations) item.id,
];

List<RecitationId> _sittingIn(List<GuidedStep> steps, int rakat) => [
  for (final step in steps)
    if (step.rakat == rakat && step.posture == PrayerPosture.sitting)
      for (final item in step.recitations) item.id,
];

int _count(List<GuidedStep> steps, PrayerPosture posture) =>
    steps.where((step) => step.posture == posture).length;

void main() {
  test('her rekâtta bir rükû ve iki secde; selâm yalnızca sonda', () {
    for (final guide in dailyPrayerGuides) {
      for (final (index, part) in guide.parts.indexed) {
        final steps = guidedPrayerSteps(guide, partIndex: index);
        final label = '${guide.prayer.name} ${part.kind.name}';
        expect(_count(steps, PrayerPosture.bowing), part.rakats, reason: label);
        expect(
          _count(steps, PrayerPosture.prostrating),
          part.rakats * 2,
          reason: label,
        );
        expect(steps.first.instructionKey, 'hoca.step.intent', reason: label);
        expect(steps[1].posture, PrayerPosture.takbir, reason: label);
        expect(steps[steps.length - 2].posture, PrayerPosture.salamRight);
        expect(steps.last.posture, PrayerPosture.salamLeft);
        expect(_count(steps, PrayerPosture.salamRight), 1, reason: label);
        // Her rükû ve secdede tesbih üç kez okunur.
        for (final step in steps) {
          for (final item in step.recitations) {
            if (item.id == RecitationId.rukuTesbih ||
                item.id == RecitationId.secdeTesbih) {
              expect(item.repeat, 3, reason: label);
            }
          }
        }
      }
    }
  });

  test('bütün namaz bölümleri sırayla kılınır', () {
    final all = guidedPrayerSteps(_guide(Prayer.isha));
    final parts = <int>[];
    for (final step in all) {
      if (parts.isEmpty || parts.last != step.partIndex) {
        parts.add(step.partIndex);
      }
    }
    expect(parts, [0, 1, 2, 3], reason: 'ilk sünnet, farz, son sünnet, vitir');
    expect(
      all.where((step) => step.instructionKey == 'hoca.step.intent'),
      hasLength(4),
      reason: 'Her bölüm kendi niyetiyle başlar.',
    );
  });

  test('sabahın sünneti: Sübhâneke yalnız ilk rekâtta', () {
    final steps = _steps(Prayer.fajr, PrayerPartKind.firstSunnah);
    expect(_standingIn(steps, 1), [
      RecitationId.subhaneke,
      RecitationId.euzuBesmele,
      RecitationId.fatiha,
      RecitationId.kevser,
    ]);
    expect(_standingIn(steps, 2), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
      RecitationId.ihlas,
    ]);
    // İki rekâtlıda ilk oturuş yoktur; ikinci rekât son oturuştur.
    expect(_sittingIn(steps, 2), [
      RecitationId.tekbir, // iki secde arası
      RecitationId.tekbir, // son oturuşa geçerken
      RecitationId.ettehiyyatu,
      RecitationId.allahummeSalli,
      RecitationId.allahummeBarik,
      RecitationId.rabbenaAtina,
      RecitationId.rabbenagfirli,
    ]);
    expect(
      steps.where((s) => s.instructionKey == 'hoca.step.firstSitting'),
      isEmpty,
    );
  });

  test('farzın üçüncü ve dördüncü rekâtında sûre okunmaz', () {
    final steps = _steps(Prayer.dhuhr, PrayerPartKind.fard);
    expect(_standingIn(steps, 2), contains(RecitationId.ihlas));
    expect(_standingIn(steps, 3), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
    ]);
    expect(_standingIn(steps, 4), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
    ]);
  });

  test('akşamın farzı: ilk oturuşta yalnız Ettehiyyâtü', () {
    final steps = _steps(Prayer.maghrib, PrayerPartKind.fard);
    final firstSitting = steps.indexWhere(
      (s) => s.instructionKey == 'hoca.step.firstSitting',
    );
    expect(steps[firstSitting].rakat, 2);
    expect(steps[firstSitting].recitations.map((r) => r.id), [
      RecitationId.tekbir,
      RecitationId.ettehiyyatu,
    ]);
    // Hemen ardından üçüncü rekâta kalkılır; salavat okunmaz.
    expect(steps[firstSitting + 1].instructionKey, 'hoca.step.standUp');
    expect(steps[firstSitting + 1].rakat, 3);
    expect(_standingIn(steps, 3), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
    ]);
  });

  test('öğlenin ilk sünneti müekkeddir: ilk oturuşta salavat yok', () {
    final steps = _steps(Prayer.dhuhr, PrayerPartKind.firstSunnah);
    expect(_sittingIn(steps, 2), [
      RecitationId.tekbir,
      RecitationId.tekbir,
      RecitationId.ettehiyyatu,
    ]);
    // Sünnette her rekâtta sûre okunur.
    expect(_standingIn(steps, 3), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
      RecitationId.felak,
    ]);
    expect(_standingIn(steps, 4).last, RecitationId.nas);
  });

  test('ikindi ve yatsının ilk sünneti gayr-i müekkeddir', () {
    for (final prayer in [Prayer.asr, Prayer.isha]) {
      final steps = _steps(prayer, PrayerPartKind.firstSunnah);
      expect(_sittingIn(steps, 2), [
        RecitationId.tekbir,
        RecitationId.tekbir,
        RecitationId.ettehiyyatu,
        RecitationId.allahummeSalli,
        RecitationId.allahummeBarik,
      ], reason: prayer.name);
      expect(_standingIn(steps, 3), [
        RecitationId.tekbir,
        RecitationId.subhaneke,
        RecitationId.euzuBesmele,
        RecitationId.fatiha,
        RecitationId.felak,
      ], reason: prayer.name);
    }
    // Öğlenin ilk sünneti ve farzlar böyle değildir.
    expect(
      _guide(Prayer.dhuhr).parts
          .where((part) => part.nonConfirmed)
          .map((part) => part.kind),
      isEmpty,
    );
  });

  test('vitirin üçüncü rekâtında sûreden sonra tekbir ve kunut', () {
    final steps = _steps(Prayer.isha, PrayerPartKind.witr);
    expect(_standingIn(steps, 3), [
      RecitationId.tekbir,
      RecitationId.besmele,
      RecitationId.fatiha,
      RecitationId.felak,
      RecitationId.kunut,
    ]);
    final qunut = steps.indexWhere(
      (s) => s.instructionKey == 'hoca.step.qunut',
    );
    expect(steps[qunut - 1].posture, PrayerPosture.takbir);
    expect(steps[qunut + 1].posture, PrayerPosture.bowing);
    // Kunut yalnızca vitirdedir.
    for (final guide in dailyPrayerGuides) {
      for (final step in guidedPrayerSteps(guide)) {
        if (step.part.kind == PrayerPartKind.witr) continue;
        expect(
          step.recitations.map((r) => r.id),
          isNot(contains(RecitationId.kunut)),
        );
      }
    }
  });

  test('sûreler rekâtlarda Mushaf sırasıyla okunur', () {
    // Ters sırayla okumak mekruhtur.
    final steps = _steps(Prayer.isha, PrayerPartKind.firstSunnah);
    final order = [
      for (final step in steps)
        if (step.instructionKey == 'hoca.step.surah')
          zammSurahs.indexOf(step.recitations.single.id),
    ];
    expect(order, [0, 1, 2, 3]);
  });

  test('niyet cümlesi bölüme ve vakte göre seçilir', () {
    expect(
      intentKeyFor(_guide(Prayer.fajr), _guide(Prayer.fajr).parts[0]),
      'hoca.intent.sunnah',
    );
    expect(
      intentKeyFor(_guide(Prayer.maghrib), _guide(Prayer.maghrib).parts[1]),
      'hoca.intent.sunnah',
    );
    expect(
      intentKeyFor(_guide(Prayer.dhuhr), _guide(Prayer.dhuhr).parts[0]),
      'hoca.intent.firstSunnah',
    );
    expect(
      intentKeyFor(_guide(Prayer.dhuhr), _guide(Prayer.dhuhr).parts[2]),
      'hoca.intent.finalSunnah',
    );
    expect(
      intentKeyFor(_guide(Prayer.isha), _guide(Prayer.isha).parts[3]),
      'hoca.intent.witr',
    );

    final tr = AppLocalizations(const Locale('tr'));
    expect(
      tr.text('hoca.intent.fard', {
        'prayer': tr.text(intentPrayerKey(Prayer.fajr)),
      }),
      'Niyet ettim Allah rızası için bugünkü sabah namazının farzını kılmaya.',
    );
  });

  test('her adımın metni üç dilde var ve okunanlar eksiksiz', () {
    for (final code in ['tr', 'en', 'ar']) {
      final l10n = AppLocalizations(Locale(code));
      for (final guide in dailyPrayerGuides) {
        expect(l10n.text(intentPrayerKey(guide.prayer)), isNot(contains('.')));
        for (final step in guidedPrayerSteps(guide)) {
          expect(
            l10n.text(step.instructionKey),
            isNot(step.instructionKey),
            reason: '$code: ${step.instructionKey}',
          );
          expect(
            l10n.text('hoca.posture.${step.posture.name}'),
            isNot(startsWith('hoca.')),
          );
          for (final item in step.recitations) {
            expect(item.recitation.isComplete, isTrue, reason: '${item.id}');
          }
        }
      }
    }
  });

  test('adım süresi okunanla uzar, hızla kısalır', () {
    final steps = _steps(Prayer.fajr, PrayerPartKind.fard);
    final fatiha = steps.firstWhere(
      (s) => s.instructionKey == 'hoca.step.fatiha',
    );
    final takbir = steps[1];
    expect(
      guidedStepDuration(fatiha),
      greaterThan(guidedStepDuration(takbir) * 4),
    );
    expect(
      guidedStepDuration(fatiha, speed: 2).inMilliseconds,
      closeTo(guidedStepDuration(fatiha).inMilliseconds / 2, 1),
    );
    expect(
      guidedStepDuration(fatiha, speed: .5),
      guidedStepDuration(fatiha) * 2,
    );
    // Tesbih üç kez okunur; süre bunu hesaba katar.
    final bow = steps.firstWhere((s) => s.posture == PrayerPosture.bowing);
    expect(guidedStepDuration(bow), greaterThan(const Duration(seconds: 7)));
  });
}
