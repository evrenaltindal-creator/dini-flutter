import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/storage_provider.dart';
import '../data/tasbih_repository.dart';
import '../domain/tasbih.dart';

class TasbihPage extends ConsumerStatefulWidget {
  const TasbihPage({super.key});
  @override
  ConsumerState<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends ConsumerState<TasbihPage> {
  late final LocalTasbihRepository repository;
  TasbihSession? session;
  List<TasbihHistoryEntry> history = [];
  @override
  void initState() {
    super.initState();
    repository = LocalTasbihRepository(ref.read(localStorageProvider));
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    final entries = await repository.history();
    if (mounted) {
      setState(() {
        session = value;
        history = entries;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = session;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final option = defaultDhikr.firstWhere(
      (item) => item.id == current.dhikrId,
      orElse: () => defaultDhikr.first,
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tesbih', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: option.id,
            decoration: const InputDecoration(labelText: 'Zikir seçimi'),
            items: defaultDhikr
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.label)),
                )
                .toList(),
            onChanged: (id) async {
              if (id == null) return;
              final next = current.copyWith(dhikrId: id);
              setState(() => session = next);
              await repository.save(next);
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${current.count}',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          Center(child: Text('Hedef: ${current.target}')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                tooltip: 'Bir azalt',
                onPressed: current.count == 0
                    ? null
                    : () => _change(current.decrement()),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                tooltip: 'Bir artır',
                onPressed: () => _increment(current),
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Sıfırla',
                onPressed: () => _change(current.reset()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: '${current.target}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hedef'),
            onFieldSubmitted: (value) async {
              final target = int.tryParse(value);
              if (target == null || target < 1) return;
              final next = current.copyWith(target: target);
              setState(() => session = next);
              await repository.save(next);
            },
          ),
          SwitchListTile(
            title: const Text('Hafif dokunsal geri bildirim'),
            value: current.hapticEnabled,
            onChanged: (value) async {
              final next = current.copyWith(hapticEnabled: value);
              setState(() => session = next);
              await repository.save(next);
            },
          ),
          if (history.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Son oturumlar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...history
                        .take(5)
                        .map(
                          (item) => Text(
                            '${item.count} · ${item.completedAt.toLocal()}',
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _increment(TasbihSession current) async {
    final next = current.increment();
    setState(() => session = next);
    if (current.hapticEnabled) await HapticFeedback.selectionClick();
    await repository.save(next);
    if (next.count >= next.target) {
      await repository.addHistory(
        TasbihHistoryEntry(
          dhikrId: next.dhikrId,
          count: next.count,
          target: next.target,
          completedAt: DateTime.now(),
        ),
      );
      history = await repository.history();
      setState(() {});
    }
  }

  Future<void> _change(TasbihSession next) async {
    setState(() => session = next);
    await repository.save(next);
  }
}
