import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../home/presentation/mosque_backdrop.dart';
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
      return const BackdropScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final option = defaultDhikr.firstWhere(
      (item) => item.id == current.dhikrId,
      orElse: () => defaultDhikr.first,
    );
    return BackdropScaffold(
      title: context.l10n.text('home.tasbih'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.l10n.text('home.tasbih'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // Dar ekranda, Arapça etiketlerde ve büyük yazı ölçeğinde
              // açılır liste yatayda taşıyordu; isExpanded onu mevcut
              // genişliğe sığdırır, ellipsis ise uzun adı keser.
              isExpanded: true,
              initialValue: option.id,
              decoration: InputDecoration(
                labelText: context.l10n.text('tasbih.select'),
              ),
              items: defaultDhikr
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        context.l10n.text('dhikr.${item.id}'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            Center(
              child: Text(
                '${context.l10n.text('tasbih.target')}: ${current.target}',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  tooltip: context.l10n.text('tasbih.decrease'),
                  onPressed: current.count == 0
                      ? null
                      : () => _change(current.decrement()),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  tooltip: context.l10n.text('tasbih.increase'),
                  onPressed: () => _increment(current),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: context.l10n.text('tasbih.reset'),
                  onPressed: () => _change(current.reset()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: '${current.target}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.text('tasbih.target'),
              ),
              onFieldSubmitted: (value) async {
                final target = int.tryParse(value);
                if (target == null || target < 1) return;
                final next = current.copyWith(target: target);
                setState(() => session = next);
                await repository.save(next);
              },
            ),
            SwitchListTile(
              title: Text(context.l10n.text('tasbih.haptic')),
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
                        context.l10n.text('tasbih.history'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...history
                          .take(5)
                          .map(
                            (item) => Text(
                              '${item.count} · '
                              '${_formatCompletedAt(context, item.completedAt)}',
                            ),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _increment(TasbihSession current) async {
    final next = current.increment();
    setState(() => session = next);
    // Sayımın kaydedilmesi dokunsal geri bildirime bağlı olmamalı: haptic
    // çağrısı desteklenmeyen bir platformda askıda kalırsa veya hata verirse
    // altındaki save() hiç çalışmıyor ve sayaç kalıcı olmuyordu.
    if (current.hapticEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
    await repository.save(next);
    // Hedefe ulaşıldığı an bir kez kaydedilir. Koşul ">=" olduğunda hedefi
    // geçen her dokunuş geçmişe ayrı bir kayıt daha yazıyordu.
    if (next.count == next.target) {
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

  /// Geçmiş kaydının tarihi. Ham `DateTime.toLocal()` kullanıcıya
  /// "2026-09-14 10:23:45.123456" gibi mikrosaniyeli bir çıktı gösteriyordu.
  String _formatCompletedAt(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${context.l10n.month(local.month)} · $hour:$minute';
  }
}
