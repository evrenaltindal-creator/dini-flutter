import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import '../../../shared/models/domain.dart';
import '../data/flutter_local_notification_service.dart';
import '../data/notification_preferences_repository.dart';
import '../domain/notification_system.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  late final NotificationPreferencesRepository repository;
  final service = FlutterLocalNotificationService();
  NotificationPreferences? preferences;
  bool permissionRequested = false;
  @override
  void initState() {
    super.initState();
    repository = NotificationPreferencesRepository(
      ref.read(localStorageProvider),
    );
    service.initialize();
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    if (mounted) setState(() => preferences = value);
  }

  @override
  Widget build(BuildContext context) {
    final value = preferences;
    if (value == null) return const Center(child: CircularProgressIndicator());
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Bildirimler',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Namaz vakitlerini cihazınızda hesaplayarak size yerel bildirim gönderebiliriz.',
          ),
          const SizedBox(height: 16),
          ...notificationPrayers.map(
            (prayer) => _PrayerNotificationTile(
              prayer: prayer,
              value: value.forPrayer(prayer),
              onChanged: (next) => _update(
                value.copyWith(prayers: {...value.prayers, prayer: next}),
              ),
            ),
          ),
          DropdownButtonFormField<NotificationSound>(
            initialValue: value.sound,
            decoration: const InputDecoration(labelText: 'Bildirim sesi'),
            items: NotificationSound.values
                .map(
                  (sound) => DropdownMenuItem(
                    value: sound,
                    child: Text(_soundLabel(sound)),
                  ),
                )
                .toList(),
            onChanged: (sound) {
              if (sound != null) _update(value.copyWith(sound: sound));
            },
          ),
          SwitchListTile(
            title: const Text('Cuma hatırlatıcısı'),
            value: value.fridayReminder,
            onChanged: (enabled) =>
                _update(value.copyWith(fridayReminder: enabled)),
          ),
          SwitchListTile(
            title: const Text('Ramazan sahur/Fajr yaklaşma'),
            value: value.ramadanSuhoorReminder,
            onChanged: (enabled) =>
                _update(value.copyWith(ramadanSuhoorReminder: enabled)),
          ),
          SwitchListTile(
            title: const Text('Ramazan iftar/Maghrib yaklaşma'),
            value: value.ramadanIftarReminder,
            onChanged: (enabled) =>
                _update(value.copyWith(ramadanIftarReminder: enabled)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: permissionRequested ? null : _requestPermission,
            icon: const Icon(Icons.notifications_outlined),
            label: Text(
              permissionRequested
                  ? 'İzin durumu işlendi'
                  : 'Bildirim izinlerini yönet',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bildirimler yerel olarak planlanır. Tam uzunlukta ezan sesinin arka planda her platformda garanti edilemeyeceğini unutmayın.',
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yerel bildirim izni'),
        content: const Text(
          'Namaz vakitlerini cihazınızda hesaplayarak size yerel bildirim gönderebiliriz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    final status = await service.requestPermission();
    setState(() => permissionRequested = true);
    if (status == NotificationPermissionStatus.granted) {
      await _reschedule(preferences!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_permissionLabel(status))));
    }
  }

  Future<void> _update(NotificationPreferences next) async {
    setState(() => preferences = next);
    await repository.save(next);
    if (permissionRequested) await _reschedule(next);
  }

  Future<void> _reschedule(NotificationPreferences value) async {
    final settings = ref.read(effectivePrayerSettingsProvider);
    final coordinates = Coordinates(
      settings.location.latitude ?? 41.0082,
      settings.location.longitude ?? 28.9784,
    );
    final start = TimezoneService.inLocation(
      settings.location.timezoneId ?? 'Europe/Istanbul',
      DateTime.now(),
    );
    await PrayerNotificationCoordinator(
      service: service,
      calculator: const LocalPrayerTimesCalculator(),
    ).reschedule(
      start: start,
      coordinates: coordinates,
      settings: settings,
      preferences: value,
    );
  }

  String _soundLabel(NotificationSound sound) => switch (sound) {
    NotificationSound.defaultSound => 'Varsayılan',
    NotificationSound.bundled => 'Bundled ses (platform izin verirse)',
    NotificationSound.silent => 'Sessiz',
  };
  String _permissionLabel(NotificationPermissionStatus status) =>
      switch (status) {
        NotificationPermissionStatus.granted => 'Bildirim izni verildi.',
        NotificationPermissionStatus.denied => 'Bildirim izni verilmedi.',
        NotificationPermissionStatus.permanentlyDenied =>
          'Bildirim izni ayarlardan etkinleştirilmeli.',
        NotificationPermissionStatus.unknown =>
          'Bildirim izin durumu bilinmiyor.',
      };
}

class _PrayerNotificationTile extends StatelessWidget {
  final Prayer prayer;
  final PrayerNotificationPreference value;
  final ValueChanged<PrayerNotificationPreference> onChanged;
  const _PrayerNotificationTile({
    required this.prayer,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(_label(prayer)),
            value: value.enabled,
            onChanged: (enabled) => onChanged(value.copyWith(enabled: enabled)),
          ),
          DropdownButtonFormField<int?>(
            initialValue: value.reminderMinutes,
            decoration: const InputDecoration(labelText: 'Önceden hatırlat'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('Yok')),
              DropdownMenuItem(value: 5, child: Text('5 dakika')),
              DropdownMenuItem(value: 10, child: Text('10 dakika')),
              DropdownMenuItem(value: 15, child: Text('15 dakika')),
              DropdownMenuItem(value: 30, child: Text('30 dakika')),
            ],
            onChanged: (minutes) => onChanged(
              value.copyWith(
                reminderMinutes: minutes,
                clearReminder: minutes == null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  String _label(Prayer prayer) => switch (prayer) {
    Prayer.fajr => 'Sabah',
    Prayer.dhuhr => 'Öğle',
    Prayer.asr => 'İkindi',
    Prayer.maghrib => 'Akşam',
    Prayer.isha => 'Yatsı',
    Prayer.sunrise => 'Güneş doğuşu',
  };
}
