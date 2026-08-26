import 'package:dini_flutter/features/calendar/domain/islamic_calendar.dart';
import 'package:dini_flutter/features/content/domain/content_repository.dart';
import 'package:dini_flutter/features/home/domain/mosque_scene_state.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage implements LocalStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  final day = DateTime(2026, 8, 26);
  final times = PrayerTimes(day, {
    Prayer.fajr: DateTime(2026, 8, 26, 4),
    Prayer.sunrise: DateTime(2026, 8, 26, 5, 30),
    Prayer.dhuhr: DateTime(2026, 8, 26, 13),
    Prayer.asr: DateTime(2026, 8, 26, 17),
    Prayer.maghrib: DateTime(2026, 8, 26, 20),
    Prayer.isha: DateTime(2026, 8, 26, 21, 30),
  });

  test('scene resolver changes at every exact prayer boundary', () {
    const resolver = MosqueSceneStateResolver();
    final cases = <DateTime, MosqueScenePeriod>{
      DateTime(2026, 8, 26, 3, 59, 59): MosqueScenePeriod.preFajrNight,
      DateTime(2026, 8, 26, 4): MosqueScenePeriod.fajr,
      DateTime(2026, 8, 26, 5, 30): MosqueScenePeriod.sunrise,
      DateTime(2026, 8, 26, 12): MosqueScenePeriod.day,
      DateTime(2026, 8, 26, 13): MosqueScenePeriod.dhuhr,
      DateTime(2026, 8, 26, 17): MosqueScenePeriod.asr,
      DateTime(2026, 8, 26, 18): MosqueScenePeriod.goldenHour,
      DateTime(2026, 8, 26, 20): MosqueScenePeriod.maghrib,
      DateTime(2026, 8, 26, 20, 0, 1): MosqueScenePeriod.ishaNight,
      DateTime(2026, 8, 26, 22): MosqueScenePeriod.ishaNight,
    };
    for (final entry in cases.entries) {
      expect(resolver.resolve(entry.key, times).period, entry.value);
    }
  });

  test('sun progression is normalized and sunset hides it', () {
    const resolver = MosqueSceneStateResolver();
    final sunrise = resolver.resolve(times.times[Prayer.sunrise]!, times);
    final noon = resolver.resolve(times.times[Prayer.dhuhr]!, times);
    final afterSunset = resolver.resolve(
      DateTime(2026, 8, 26, 20, 0, 1),
      times,
    );
    expect(sunrise.sunProgress, inInclusiveRange(0, 1));
    expect(noon.sunProgress, greaterThan(sunrise.sunProgress));
    expect(afterSunset.sunProgress, 0);
    expect(
      resolver.resolve(DateTime(2026, 8, 26, 16), times).sunProgress,
      lessThan(1),
    );
  });

  test('daily content is deterministic for the same date and changes predictably by date', () {
    final first = OfflineContentRepository.dailyFor(day);
    final second = OfflineContentRepository.dailyFor(day);
    final sameDateLater = OfflineContentRepository.dailyFor(
      DateTime(2026, 8, 26, 23, 59),
    );
    final nextDate = OfflineContentRepository.dailyFor(
      day.add(const Duration(days: 1)),
    );
    expect(first.id, second.id);
    expect(first.id, sameDateLater.id);
    expect(first.shareText, second.shareText);
    expect(nextDate.id, isNot(first.id));
  });

  test('bundled content has complete source metadata', () {
    expect(OfflineContentRepository.verses, hasLength(1));
    expect(OfflineContentRepository.hadiths, hasLength(1));
    expect(OfflineContentRepository.duas, hasLength(1));
    for (final verse in OfflineContentRepository.verses) {
      expect(verse.surah, isNotEmpty);
      expect(verse.ayah, greaterThan(0));
      expect(verse.translation, isNotEmpty);
    }
    for (final hadith in OfflineContentRepository.hadiths) {
      expect(hadith.book, isNotEmpty);
      expect(hadith.reference, isNotNull);
    }
    for (final dua in OfflineContentRepository.duas) {
      expect(dua.source, isNotEmpty);
    }
  });

  test(
    'favorites survive repository recreation for verse, hadith and dua',
    () async {
      final storage = MemoryStorage();
      for (var index = 0; index < 3; index++) {
        final content = OfflineContentRepository.dailyFor(
          DateTime(2020, 1, 1 + index),
        );
        await OfflineContentRepository(storage).setFavorite(content.id, true);
        expect(
          await OfflineContentRepository(storage).isFavorite(content.id),
          isTrue,
        );
        await OfflineContentRepository(storage).setFavorite(content.id, false);
        expect(
          await OfflineContentRepository(storage).isFavorite(content.id),
          isFalse,
        );
      }
    },
  );

  test(
    'islamic calendar provides local date, Ramadan boundaries and Friday state',
    () {
      const calendar = IslamicCalendar();
      expect(calendar.isFriday(DateTime(2026, 8, 28)), isTrue);
      final date = calendar.hijri(day);
      expect(date.year, greaterThan(1400));
      expect(date.month, inInclusiveRange(1, 12));
      expect(date.day, inInclusiveRange(1, 30));
      expect(calendar.isRamadan(DateTime(2026, 2, 17)), isFalse);
      expect(calendar.ramadanDay(DateTime(2026, 2, 18)), 1);
      expect(calendar.ramadanDay(DateTime(2026, 3, 10)), 21);
      expect(calendar.ramadanDay(DateTime(2026, 3, 19)), 30);
      expect(calendar.isRamadan(DateTime(2026, 3, 20)), isFalse);
    },
  );

  test('Friday follows selected prayer-location timezone date', () {
    final selectedLocationNow = TimezoneService.inLocation(
      'America/New_York',
      DateTime.utc(2026, 8, 29, 2),
    );
    expect(selectedLocationNow.weekday, DateTime.friday);
  });
}
