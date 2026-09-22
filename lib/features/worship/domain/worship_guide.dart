import '../../../shared/models/domain.dart';

enum PrayerPartKind { firstSunnah, fard, finalSunnah, witr }

class PrayerPart {
  final PrayerPartKind kind;
  final int rakats;

  /// Gayr-i müekked (kuvvetli olmayan) sünnet mi? İkindinin ve yatsının ilk
  /// sünneti böyledir: ilk oturuşta Ettehiyyâtü'nün ardından salavatlar da
  /// okunur ve üçüncü rekât Sübhâneke ile başlar (Diyanet, Namaz İlmihali).
  final bool nonConfirmed;

  const PrayerPart(this.kind, this.rakats, {this.nonConfirmed = false});
}

class DailyPrayerGuide {
  final Prayer prayer;
  final List<PrayerPart> parts;

  const DailyPrayerGuide(this.prayer, this.parts);

  int get totalRakats => parts.fold(0, (sum, part) => sum + part.rakats);
}

const dailyPrayerGuides = <DailyPrayerGuide>[
  DailyPrayerGuide(Prayer.fajr, [
    PrayerPart(PrayerPartKind.firstSunnah, 2),
    PrayerPart(PrayerPartKind.fard, 2),
  ]),
  DailyPrayerGuide(Prayer.dhuhr, [
    PrayerPart(PrayerPartKind.firstSunnah, 4),
    PrayerPart(PrayerPartKind.fard, 4),
    PrayerPart(PrayerPartKind.finalSunnah, 2),
  ]),
  DailyPrayerGuide(Prayer.asr, [
    PrayerPart(PrayerPartKind.firstSunnah, 4, nonConfirmed: true),
    PrayerPart(PrayerPartKind.fard, 4),
  ]),
  DailyPrayerGuide(Prayer.maghrib, [
    PrayerPart(PrayerPartKind.fard, 3),
    PrayerPart(PrayerPartKind.finalSunnah, 2),
  ]),
  DailyPrayerGuide(Prayer.isha, [
    PrayerPart(PrayerPartKind.firstSunnah, 4, nonConfirmed: true),
    PrayerPart(PrayerPartKind.fard, 4),
    PrayerPart(PrayerPartKind.finalSunnah, 2),
    PrayerPart(PrayerPartKind.witr, 3),
  ]),
];
