import '../../../shared/models/domain.dart';
import 'prayer_flow.dart';
import 'worship_guide.dart';

/// Namaz hocasının ekranda gösterdiği duruş.
///
/// Figür bu duruşlar arasında canlandırılır; her adım bir duruşta geçer.
enum PrayerPosture {
  /// Ayakta, kollar yanda: niyet ve rükûdan doğruluş (kavme).
  upright,

  /// Eller kulak hizasında: tekbir.
  takbir,

  /// Kıyam: ayakta, eller bağlı.
  standing,

  /// Rükû.
  bowing,

  /// Secde.
  prostrating,

  /// Oturuş: iki secde arası (celse) ve ka'de.
  sitting,

  /// Sağa selâm.
  salamRight,

  /// Sola selâm.
  salamLeft,
}

/// Bir adımda okunacak metin ve kaç kez okunacağı.
class GuidedRecitation {
  final RecitationId id;
  final int repeat;

  const GuidedRecitation(this.id, {this.repeat = 1});

  Recitation get recitation => recitationLibrary[id]!;

  @override
  bool operator ==(Object other) =>
      other is GuidedRecitation && other.id == id && other.repeat == repeat;

  @override
  int get hashCode => Object.hash(id, repeat);

  @override
  String toString() => repeat == 1 ? id.name : '${id.name}×$repeat';
}

/// Namaz hocasının tek bir adımı: duruş, ne yapılacağı ve ne okunacağı.
class GuidedStep {
  final PrayerPosture posture;

  /// Ne yapılacağını anlatan yerelleştirme anahtarı (`hoca.step.*`).
  final String instructionKey;

  /// Bu adımda sırayla okunacak metinler; boş olabilir (niyet).
  final List<GuidedRecitation> recitations;

  /// Namazın kaçıncı bölümü (ilk sünnet, farz ...), sıfırdan.
  final int partIndex;
  final PrayerPart part;

  /// Kaçıncı rekât; niyet ve başlangıç tekbirinde 1'dir.
  final int rakat;

  const GuidedStep({
    required this.posture,
    required this.instructionKey,
    required this.partIndex,
    required this.part,
    required this.rakat,
    this.recitations = const [],
  });

  @override
  String toString() =>
      '${part.kind.name}#$rakat ${posture.name} '
      '${instructionKey.replaceFirst('hoca.step.', '')} $recitations';
}

/// Fâtiha'dan sonra rekât sırasıyla okunan sûreler (Mushaf sırası).
const zammSurahs = [
  RecitationId.kevser,
  RecitationId.ihlas,
  RecitationId.felak,
  RecitationId.nas,
];

const _tekbir = GuidedRecitation(RecitationId.tekbir);

/// Bir namazın bölümlerini, hocanın kıldırdığı sırayla adım adım açar.
///
/// [partIndex] verilirse yalnızca o bölüm (ör. sabahın farzı) kılınır.
///
/// Kurallar Diyanet İşleri Başkanlığı'nın Hanefî anlatımını (Namaz İlmihali)
/// izler:
/// * Sübhâneke ve Eûzü yalnız ilk rekâtta okunur; sonraki rekâtlar Besmele
///   ve Fâtiha ile başlar.
/// * Farzların üçüncü ve dördüncü rekâtında Fâtiha'dan sonra sûre okunmaz;
///   sünnetlerde ve vitirde her rekâtta okunur.
/// * Üç ve dört rekâtlı namazlarda ikinci rekâttan sonra ilk oturuş vardır
///   ve orada yalnız Ettehiyyâtü okunur. Gayr-i müekked sünnette (ikindi ve
///   yatsının ilk sünneti) salavatlar da okunur ve üçüncü rekât Sübhâneke
///   ile başlar.
/// * Vitirin üçüncü rekâtında sûreden sonra eller kaldırılarak tekbir alınır
///   ve kunut duaları okunur.
/// * Son oturuşta Ettehiyyâtü, salavatlar ve Rabbenâ duaları okunur; önce
///   sağa sonra sola selâm verilir.
List<GuidedStep> guidedPrayerSteps(DailyPrayerGuide guide, {int? partIndex}) {
  final steps = <GuidedStep>[];
  for (final (index, part) in guide.parts.indexed) {
    if (partIndex != null && index != partIndex) continue;
    steps.addAll(_partSteps(index, part));
  }
  return steps;
}

List<GuidedStep> _partSteps(int partIndex, PrayerPart part) {
  final steps = <GuidedStep>[];
  void add(
    PrayerPosture posture,
    String key,
    int rakat, [
    List<GuidedRecitation> recitations = const [],
  ]) => steps.add(
    GuidedStep(
      posture: posture,
      instructionKey: 'hoca.step.$key',
      partIndex: partIndex,
      part: part,
      rakat: rakat,
      recitations: recitations,
    ),
  );

  final isFard = part.kind == PrayerPartKind.fard;
  final isWitr = part.kind == PrayerPartKind.witr;

  add(PrayerPosture.upright, 'intent', 1);
  add(PrayerPosture.takbir, 'openingTakbir', 1, [_tekbir]);

  for (var rakat = 1; rakat <= part.rakats; rakat++) {
    final opensWithSubhaneke = rakat == 1 || (rakat == 3 && part.nonConfirmed);

    // Kıyam. İlk rekât dışında önce "Allahu Ekber" diyerek ayağa kalkılır.
    final opening = <GuidedRecitation>[
      if (rakat > 1) _tekbir,
      if (opensWithSubhaneke) ...const [
        GuidedRecitation(RecitationId.subhaneke),
        GuidedRecitation(RecitationId.euzuBesmele),
      ] else
        const GuidedRecitation(RecitationId.besmele),
    ];
    add(PrayerPosture.standing, rakat == 1 ? 'standing' : 'standUp', rakat, [
      ...opening,
    ]);
    add(PrayerPosture.standing, 'fatiha', rakat, const [
      GuidedRecitation(RecitationId.fatiha),
    ]);
    if (!(isFard && rakat >= 3)) {
      add(PrayerPosture.standing, 'surah', rakat, [
        GuidedRecitation(zammSurahs[(rakat - 1) % zammSurahs.length]),
      ]);
    }
    if (isWitr && rakat == part.rakats) {
      add(PrayerPosture.takbir, 'qunutTakbir', rakat, [_tekbir]);
      add(PrayerPosture.standing, 'qunut', rakat, const [
        GuidedRecitation(RecitationId.kunut),
      ]);
    }

    // Rükû, kavme, iki secde ve arada celse.
    add(PrayerPosture.bowing, 'bow', rakat, const [
      _tekbir,
      GuidedRecitation(RecitationId.rukuTesbih, repeat: 3),
    ]);
    add(PrayerPosture.upright, 'rise', rakat, const [
      GuidedRecitation(RecitationId.semiallahu),
      GuidedRecitation(RecitationId.rabbenaLekelHamd),
    ]);
    add(PrayerPosture.prostrating, 'prostrate', rakat, const [
      _tekbir,
      GuidedRecitation(RecitationId.secdeTesbih, repeat: 3),
    ]);
    add(PrayerPosture.sitting, 'sitBetween', rakat, const [_tekbir]);
    add(PrayerPosture.prostrating, 'prostrateAgain', rakat, const [
      _tekbir,
      GuidedRecitation(RecitationId.secdeTesbih, repeat: 3),
    ]);

    if (rakat == part.rakats) {
      add(PrayerPosture.sitting, 'finalSitting', rakat, const [
        _tekbir,
        GuidedRecitation(RecitationId.ettehiyyatu),
      ]);
      add(PrayerPosture.sitting, 'salawat', rakat, const [
        GuidedRecitation(RecitationId.allahummeSalli),
        GuidedRecitation(RecitationId.allahummeBarik),
      ]);
      add(PrayerPosture.sitting, 'rabbena', rakat, const [
        GuidedRecitation(RecitationId.rabbenaAtina),
        GuidedRecitation(RecitationId.rabbenagfirli),
      ]);
      add(PrayerPosture.salamRight, 'salamRight', rakat, const [
        GuidedRecitation(RecitationId.selam),
      ]);
      add(PrayerPosture.salamLeft, 'salamLeft', rakat, const [
        GuidedRecitation(RecitationId.selam),
      ]);
    } else if (rakat == 2) {
      add(PrayerPosture.sitting, 'firstSitting', rakat, const [
        _tekbir,
        GuidedRecitation(RecitationId.ettehiyyatu),
      ]);
      if (part.nonConfirmed) {
        add(PrayerPosture.sitting, 'salawat', rakat, const [
          GuidedRecitation(RecitationId.allahummeSalli),
          GuidedRecitation(RecitationId.allahummeBarik),
        ]);
      }
    }
  }
  return steps;
}

/// Niyet cümlesinin yerelleştirme anahtarı.
///
/// Tek sünneti olan vakitlerde (sabah, ikindi, akşam) "ilk/son" denmez,
/// yalnızca "sünneti" denir.
String intentKeyFor(DailyPrayerGuide guide, PrayerPart part) {
  final sunnahParts = guide.parts
      .where(
        (p) =>
            p.kind == PrayerPartKind.firstSunnah ||
            p.kind == PrayerPartKind.finalSunnah,
      )
      .length;
  return switch (part.kind) {
    PrayerPartKind.fard => 'hoca.intent.fard',
    PrayerPartKind.witr => 'hoca.intent.witr',
    _ when sunnahParts == 1 => 'hoca.intent.sunnah',
    PrayerPartKind.firstSunnah => 'hoca.intent.firstSunnah',
    PrayerPartKind.finalSunnah => 'hoca.intent.finalSunnah',
  };
}

/// Niyet cümlesinde geçen vakit adının anahtarı ("sabah namazının").
///
/// Ekrandaki vakit adı kullanılamaz: sabah vakti bazı dillerde "İmsak" diye
/// gösterilebilir, niyet ise sabah namazına edilir.
String intentPrayerKey(Prayer prayer) => 'hoca.intentPrayer.${prayer.name}';

/// Adımın 1× hızda ne kadar süreceği.
///
/// Okuma süresi okunuşun uzunluğundan kestirilir (saniyede yaklaşık on bir
/// harf, ağır ve tane tane bir okuyuş); her adıma hareket için bir pay
/// eklenir. [speed] 2 ise süre yarıya iner.
Duration guidedStepDuration(GuidedStep step, {double speed = 1}) {
  var seconds = 2.5; // hareket ve yerleşme payı
  for (final item in step.recitations) {
    final letters = item.recitation.transliteration.length;
    seconds += item.repeat * (letters / 11).clamp(1.2, double.infinity);
  }
  if (step.recitations.isEmpty) seconds += 4; // niyeti okuyup düşünmek için
  final scaled = seconds / speed.clamp(.25, 4);
  return Duration(milliseconds: (scaled * 1000).round());
}
