import '../../../core/storage/local_storage.dart';
import '../domain/fasting_log.dart';

/// Oruç kaydını cihazda saklar.
///
/// Anahtar hicri yıl + gün üzerinedir, miladi tarih üzerine değil: kullanıcı
/// hicri tarih düzeltmesini değiştirdiğinde kayıt aynı güne bağlı kalmalı,
/// bir gün kaymamalıdır.
class FastingRepository {
  static const prefix = 'dini.fasting.';

  final LocalStorage storage;

  const FastingRepository(this.storage);

  String _key(int hijriYear, int day) => '$prefix$hijriYear.$day';

  Future<FastingLog> load(RamadanSpan span) async {
    final entries = <int, FastingEntry>{};
    for (var day = 1; day <= span.length; day++) {
      final entry = FastingEntry.decode(
        await storage.read(_key(span.hijriYear, day)),
      );
      if (entry != null) entries[day] = entry;
    }
    return FastingLog(span: span, entries: entries);
  }

  Future<void> saveDay(RamadanSpan span, int day, FastingEntry? entry) async {
    final key = _key(span.hijriYear, day);
    if (entry == null) {
      await storage.remove(key);
    } else {
      await storage.write(key, entry.encode());
    }
  }

  Future<void> clear(RamadanSpan span) async {
    for (var day = 1; day <= span.length; day++) {
      await storage.remove(_key(span.hijriYear, day));
    }
  }
}
