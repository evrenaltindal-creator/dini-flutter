import '../../../core/storage/local_storage.dart';

/// Namaz takibinde muaf sayılan günler.
///
/// Muaf gün, namaz kılınmayan gündür (hayız ve nifas dönemleri). Kayıtta
/// "tamamlanmamış" sayılmaz: seri bozulmamalı, çünkü eksik kalan bir şey
/// yoktur. Uygulama burada bir hüküm vermez, kullanıcının işaretini saklar.
class ExemptionRepository {
  static const prefix = 'dini.tracker.exempt.';

  final LocalStorage storage;

  const ExemptionRepository(this.storage);

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _key(DateTime date) => '$prefix${dateKey(date)}';

  Future<bool> isExempt(DateTime date) async =>
      await storage.read(_key(date)) == '1';

  Future<void> setExempt(DateTime date, bool value) async {
    final key = _key(date);
    if (value) {
      await storage.write(key, '1');
    } else {
      await storage.remove(key);
    }
  }

  /// [through] gününden geriye doğru [days] gün içindeki muaf günler.
  Future<Set<DateTime>> recent(DateTime through, {int days = 7}) async {
    final result = <DateTime>{};
    final last = DateTime(through.year, through.month, through.day);
    for (var index = 0; index < days; index++) {
      final date = last.subtract(Duration(days: index));
      if (await isExempt(date)) result.add(date);
    }
    return result;
  }
}
