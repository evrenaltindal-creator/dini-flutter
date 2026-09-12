import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../data/prayer_tracker_repository.dart';
import '../domain/prayer_tracker.dart';
import '../../../shared/models/domain.dart';

class PrayerTrackerPage extends StatelessWidget {
  const PrayerTrackerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('tracker.title'))),
    body: const SafeArea(child: PrayerTrackerView()),
  );
}

class PrayerTrackerView extends ConsumerStatefulWidget {
  const PrayerTrackerView({super.key});

  @override
  ConsumerState<PrayerTrackerView> createState() => _PrayerTrackerViewState();
}

class _PrayerTrackerViewState extends ConsumerState<PrayerTrackerView> {
  late final LocalPrayerTrackerRepository repository;
  PrayerTrackerDay? day;
  final now = DateTime.now();
  @override
  void initState() {
    super.initState();
    repository = LocalPrayerTrackerRepository(ref.read(localStorageProvider));
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load(now);
    if (mounted) setState(() => day = value);
  }

  @override
  Widget build(BuildContext context) {
    final current = day;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: current.completedCount / trackedPrayers.length,
                        strokeWidth: 7,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      Center(child: Text('${current.completedCount}/5')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.text('tracker.today'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.text('tracker.completed', {
                          'completed': current.completedCount,
                          'total': trackedPrayers.length,
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: trackedPrayers.map((prayer) {
              final checked = current.isCompleted(prayer);
              return CheckboxListTile.adaptive(
                secondary: Icon(_icon(prayer)),
                title: Text(context.l10n.prayer(prayer.name)),
                value: checked,
                onChanged: (value) async {
                  final next = current.toggle(prayer);
                  setState(() => day = next);
                  await repository.save(next);
                },
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.text('tracker.privacy'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    return content;
  }

  IconData _icon(Prayer p) => switch (p) {
    Prayer.fajr => Icons.wb_twilight,
    Prayer.dhuhr => Icons.wb_sunny,
    Prayer.asr => Icons.sunny,
    Prayer.maghrib => Icons.wb_twilight,
    Prayer.isha => Icons.nightlight_round,
    Prayer.sunrise => Icons.wb_sunny_outlined,
  };
}
