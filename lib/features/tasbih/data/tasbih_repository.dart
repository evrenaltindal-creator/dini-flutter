import '../../../core/storage/local_storage.dart';
import '../domain/tasbih.dart';

abstract class TasbihRepository {
  Future<TasbihSession> load();
  Future<void> save(TasbihSession session);
  Future<List<TasbihHistoryEntry>> history();
  Future<void> addHistory(TasbihHistoryEntry entry);
  Future<void> clear();
}

class LocalTasbihRepository implements TasbihRepository {
  final LocalStorage storage;
  const LocalTasbihRepository(this.storage);
  static const prefix = 'dini.tasbih.';
  @override
  Future<TasbihSession> load() async => TasbihSession(
    dhikrId: await storage.read('${prefix}dhikr') ?? defaultDhikr.first.id,
    count: int.tryParse(await storage.read('${prefix}count') ?? '') ?? 0,
    target: int.tryParse(await storage.read('${prefix}target') ?? '') ?? 33,
    startedAt:
        DateTime.tryParse(await storage.read('${prefix}started') ?? '') ??
        DateTime.now(),
    hapticEnabled: (await storage.read('${prefix}haptic') ?? '1') == '1',
  );
  @override
  Future<void> save(TasbihSession session) async {
    await storage.write('${prefix}dhikr', session.dhikrId);
    await storage.write('${prefix}count', '${session.count}');
    await storage.write('${prefix}target', '${session.target}');
    await storage.write(
      '${prefix}started',
      session.startedAt.toIso8601String(),
    );
    await storage.write('${prefix}haptic', session.hapticEnabled ? '1' : '0');
  }

  @override
  Future<List<TasbihHistoryEntry>> history() async {
    final count =
        int.tryParse(await storage.read('${prefix}history.count') ?? '') ?? 0;
    final result = <TasbihHistoryEntry>[];
    for (var index = 0; index < count; index++) {
      final raw = await storage.read('${prefix}history.$index');
      if (raw == null) continue;
      final parts = raw.split('|');
      if (parts.length == 4) {
        result.add(
          TasbihHistoryEntry(
            dhikrId: parts[0],
            count: int.tryParse(parts[1]) ?? 0,
            target: int.tryParse(parts[2]) ?? 33,
            completedAt:
                DateTime.tryParse(parts[3]) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }
    }
    return result.reversed.toList();
  }

  @override
  Future<void> addHistory(TasbihHistoryEntry entry) async {
    final count =
        int.tryParse(await storage.read('${prefix}history.count') ?? '') ?? 0;
    await storage.write(
      '${prefix}history.$count',
      '${entry.dhikrId}|${entry.count}|${entry.target}|${entry.completedAt.toIso8601String()}',
    );
    await storage.write('${prefix}history.count', '${count + 1}');
  }

  @override
  Future<void> clear() async {
    for (final key in [
      'dhikr',
      'count',
      'target',
      'started',
      'haptic',
      'history.count',
    ]) {
      await storage.remove('$prefix$key');
    }
    for (var index = 0; index < 365; index++) {
      await storage.remove('${prefix}history.$index');
    }
  }
}
