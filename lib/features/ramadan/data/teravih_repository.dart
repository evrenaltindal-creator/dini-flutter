import '../../../core/storage/local_storage.dart';
import '../domain/fasting_log.dart';
import '../domain/teravih.dart';

/// Teravih kaydını cihazda saklar.
///
/// Oruç kaydı gibi hicri yıl + gece anahtarıyla; miladi tarih kullanılsaydı
/// hicri tarih düzeltmesi değiştiğinde geceler kayardı.
class TeravihRepository {
  static const prefix = 'dini.teravih.';
  static const targetKey = 'dini.teravih.target';

  final LocalStorage storage;

  const TeravihRepository(this.storage);

  String _key(int hijriYear, int night) => '$prefix$hijriYear.$night';

  Future<TeravihLog> load(RamadanSpan span) async {
    final rekats = <int, int>{};
    for (var night = 1; night <= span.length; night++) {
      final value = int.tryParse(
        await storage.read(_key(span.hijriYear, night)) ?? '',
      );
      if (value != null && value > 0) rekats[night] = value;
    }
    final target =
        int.tryParse(await storage.read(targetKey) ?? '') ??
        teravihDefaultTarget;
    return TeravihLog(span: span, rekats: rekats, target: target);
  }

  Future<void> saveNight(RamadanSpan span, int night, int rekats) async {
    final key = _key(span.hijriYear, night);
    if (rekats <= 0) {
      await storage.remove(key);
    } else {
      await storage.write(key, '$rekats');
    }
  }

  Future<void> saveTarget(int target) async =>
      storage.write(targetKey, '$target');
}
