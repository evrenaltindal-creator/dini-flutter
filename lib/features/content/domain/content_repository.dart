import '../../../core/storage/local_storage.dart';
import '../../../shared/models/domain.dart';

sealed class DailyContent {
  const DailyContent();
  String get id;
  String get shareText;
}

class VerseContent extends DailyContent {
  final DailyVerse value;
  const VerseContent(this.value);
  @override
  String get id => 'verse-${value.surah}-${value.ayah}';
  @override
  String get shareText =>
      '${value.translation}\nKaynak: Kur’an, ${value.surah} ${value.ayah}';
}

class HadithContent extends DailyContent {
  final DailyHadith value;
  const HadithContent(this.value);
  @override
  String get id => 'hadith-${value.book}-${value.reference}';
  @override
  String get shareText =>
      '${value.text}\nKaynak: ${value.book}${value.reference == null ? '' : ' · ${value.reference}'}';
}

class DuaContent extends DailyContent {
  final DailyDua value;
  const DuaContent(this.value);
  @override
  String get id => 'dua-${value.meaning.hashCode}';
  @override
  String get shareText =>
      '${value.meaning}\nArapça: ${value.arabic}\nDua kaynağı: ${value.source}';
}

class OfflineContentRepository {
  final LocalStorage? storage;
  const OfflineContentRepository(this.storage);
  static const verses = [
    DailyVerse(
      'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'Kalpler ancak Allah’ı anmakla huzur bulur.',
      'Ra’d',
      28,
    ),
  ];
  static const hadiths = [
    DailyHadith(
      'Ameller niyetlere göredir.',
      'Sahih al-Bukhari',
      reference: '1',
    ),
  ];
  static const duas = [
    DailyDua(
      'رَبِّ زِدْنِي عِلْمًا',
      'Rabbi zidni ilma',
      'Rabbim, ilmimi artır.',
      'Kur’an, Taha 20:114',
    ),
  ];
  DailyContent daily(DateTime date) => dailyFor(date);
  static DailyContent dailyFor(DateTime date) {
    final calendarDate = DateTime(date.year, date.month, date.day);
    final day = calendarDate.difference(DateTime(2020, 1, 1)).inDays.abs();
    return [
      VerseContent(verses[day % verses.length]),
      HadithContent(hadiths[day % hadiths.length]),
      DuaContent(duas[day % duas.length]),
    ][day % 3];
  }

  Future<bool> isFavorite(String id) async =>
      await storage?.read('dini.favorite.$id') == '1';
  Future<void> setFavorite(String id, bool value) async {
    if (storage == null) return;
    final indexKey = 'dini.favorites.index';
    final ids = ((await storage!.read(indexKey)) ?? '')
        .split(',')
        .where((item) => item.isNotEmpty)
        .toSet();
    if (value) {
      ids.add(id);
      await storage!.write('dini.favorite.$id', '1');
    } else {
      ids.remove(id);
      await storage!.remove('dini.favorite.$id');
    }
    if (ids.isEmpty) {
      await storage!.remove(indexKey);
    } else {
      await storage!.write(indexKey, ids.join(','));
    }
  }

  Future<void> clear() async {
    final ids = ((await storage?.read('dini.favorites.index')) ?? '')
        .split(',')
        .where((item) => item.isNotEmpty);
    for (final id in ids) {
      await storage?.remove('dini.favorite.$id');
    }
    await storage?.remove('dini.favorites.index');
  }
}
