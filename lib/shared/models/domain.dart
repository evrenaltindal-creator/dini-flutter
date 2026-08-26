enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

enum PrayerCalculationMethod {
  diyanet,
  muslimWorldLeague,
  ummAlQura,
  egyptian,
  karachi,
  isna,
}

enum AsrMethod { standard, hanafi }

class PrayerTimes {
  final DateTime date;
  final Map<Prayer, DateTime> times;
  final String? timezoneId;
  const PrayerTimes(this.date, this.times, {this.timezoneId});
}

class LocationPreference {
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? timezoneId;
  const LocationPreference({
    this.city,
    this.latitude,
    this.longitude,
    this.timezoneId,
  });
}

class DailyVerse {
  final String arabic, translation, surah;
  final int ayah;
  const DailyVerse(this.arabic, this.translation, this.surah, this.ayah);
}

class DailyHadith {
  final String text, book;
  final String? reference;
  const DailyHadith(this.text, this.book, {this.reference});
}

class DailyDua {
  final String arabic, transliteration, meaning, source;
  const DailyDua(this.arabic, this.transliteration, this.meaning, this.source);
}

class PrayerTrackingEntry {
  final DateTime date;
  final Prayer prayer;
  final bool completed;
  const PrayerTrackingEntry(this.date, this.prayer, this.completed);
}

class TasbihSession {
  final String dhikrId;
  final int count, target;
  const TasbihSession(this.dhikrId, this.count, this.target);
}

class PremiumEntitlement {
  final bool active;
  final String? productId;
  const PremiumEntitlement(this.active, {this.productId});
}
