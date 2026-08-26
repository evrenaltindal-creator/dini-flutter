import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../data/prayer_tracker_repository.dart';
import '../domain/prayer_tracker.dart';
import '../../../shared/models/domain.dart';

class PrayerTrackerPage extends ConsumerStatefulWidget {
  const PrayerTrackerPage({super.key});
  @override
  ConsumerState<PrayerTrackerPage> createState() => _PrayerTrackerPageState();
}

class _PrayerTrackerPageState extends ConsumerState<PrayerTrackerPage> {
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Namaz Takibi',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${current.completedCount} / ${trackedPrayers.length} tamamlandı',
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: trackedPrayers.map((prayer) {
                final checked = current.isCompleted(prayer);
                return CheckboxListTile(
                  secondary: Icon(_icon(prayer)),
                  title: Text(_label(prayer)),
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
          const Text(
            'Takip verileri seçili günün yerel tarihine göre yalnızca cihazda saklanır.',
          ),
        ],
      ),
    );
  }

  String _label(Prayer p) => switch (p) {
    Prayer.fajr => 'Sabah',
    Prayer.dhuhr => 'Öğle',
    Prayer.asr => 'İkindi',
    Prayer.maghrib => 'Akşam',
    Prayer.isha => 'Yatsı',
    Prayer.sunrise => 'Güneş doğuşu',
  };
  IconData _icon(Prayer p) => switch (p) {
    Prayer.fajr => Icons.wb_twilight,
    Prayer.dhuhr => Icons.wb_sunny,
    Prayer.asr => Icons.sunny,
    Prayer.maghrib => Icons.wb_twilight,
    Prayer.isha => Icons.nightlight_round,
    Prayer.sunrise => Icons.wb_sunny_outlined,
  };
}
