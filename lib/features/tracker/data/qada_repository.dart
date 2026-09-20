import '../../../shared/models/domain.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/prayer_tracker.dart';
import '../domain/qada.dart';

/// Kaza sayaçlarını cihazda saklar.
class QadaRepository {
  static const prefix = 'dini.qada.';

  final LocalStorage storage;

  const QadaRepository(this.storage);

  String _key(Prayer prayer) => '$prefix${prayer.name}';

  Future<QadaLog> load() async {
    final counts = <Prayer, int>{};
    for (final prayer in trackedPrayers) {
      final value = int.tryParse(await storage.read(_key(prayer)) ?? '');
      if (value != null && value > 0) counts[prayer] = value;
    }
    return QadaLog(counts: counts);
  }

  Future<void> save(QadaLog log) async {
    for (final prayer in trackedPrayers) {
      final key = _key(prayer);
      final value = log.countOf(prayer);
      if (value > 0) {
        await storage.write(key, '$value');
      } else {
        await storage.remove(key);
      }
    }
  }
}
