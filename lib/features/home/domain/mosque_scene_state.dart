import '../../../shared/models/domain.dart';

enum MosqueScenePeriod {
  preFajrNight,
  fajr,
  sunrise,
  day,
  dhuhr,
  asr,
  goldenHour,
  maghrib,
  ishaNight,
}

class MosqueSceneState {
  final MosqueScenePeriod period;
  final double sunProgress,
      moonVisibility,
      starVisibility,
      skyProgress,
      mosqueLightingLevel,
      foregroundBrightness;
  final bool friday, ramadan;
  const MosqueSceneState({
    required this.period,
    required this.sunProgress,
    required this.moonVisibility,
    required this.starVisibility,
    required this.skyProgress,
    required this.mosqueLightingLevel,
    required this.foregroundBrightness,
    required this.friday,
    required this.ramadan,
  });
}

class MosqueSceneStateResolver {
  const MosqueSceneStateResolver();
  MosqueSceneState resolve(
    DateTime now,
    PrayerTimes times, {
    bool friday = false,
    bool ramadan = false,
  }) {
    final f = times.times[Prayer.fajr]!,
        s = times.times[Prayer.sunrise]!,
        d = times.times[Prayer.dhuhr]!,
        a = times.times[Prayer.asr]!,
        m = times.times[Prayer.maghrib]!;
    MosqueScenePeriod period;
    double sun;
    if (now.isBefore(f)) {
      period = MosqueScenePeriod.preFajrNight;
      sun = 0;
    } else if (now.isBefore(s)) {
      period = MosqueScenePeriod.fajr;
      sun = 0;
    } else if (now.isAtSameMomentAs(s)) {
      period = MosqueScenePeriod.sunrise;
      sun = 0;
    } else if (now.isBefore(d)) {
      period = MosqueScenePeriod.day;
      sun = 0.5 * _between(now, s, d).toDouble();
    } else if (now.isBefore(a)) {
      period = MosqueScenePeriod.dhuhr;
      sun = 0.5 + 0.15 * _between(now, d, a).toDouble();
    } else if (now.isAtSameMomentAs(a)) {
      period = MosqueScenePeriod.asr;
      sun = 0.65;
    } else if (now.isBefore(m)) {
      period = MosqueScenePeriod.goldenHour;
      sun = 0.65 + 0.35 * _between(now, a, m).toDouble();
    } else if (now.isAtSameMomentAs(m)) {
      period = MosqueScenePeriod.maghrib;
      sun = 1;
    } else {
      period = MosqueScenePeriod.ishaNight;
      sun = 0;
    }
    final night =
        period == MosqueScenePeriod.preFajrNight ||
        period == MosqueScenePeriod.ishaNight;
    final stars = night
        ? 1
        : (period == MosqueScenePeriod.fajr ? 1 - _between(now, f, s) : 0);
    final moon = night ? 0.9 : (period == MosqueScenePeriod.fajr ? 0.5 : 0);
    final light = night
        ? 0.9
        : (period == MosqueScenePeriod.goldenHour ? 0.45 : 0.15);
    return MosqueSceneState(
      period: period,
      sunProgress: sun.clamp(0, 1).toDouble(),
      moonVisibility: moon.toDouble(),
      starVisibility: stars.clamp(0, 1).toDouble(),
      skyProgress: _between(now, f, m).toDouble(),
      mosqueLightingLevel: light,
      foregroundBrightness: night ? 0.65 : 0.95,
      friday: friday,
      ramadan: ramadan,
    );
  }

  double _between(DateTime value, DateTime start, DateTime end) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return value.difference(start).inSeconds.clamp(0, total) / total;
  }
}
