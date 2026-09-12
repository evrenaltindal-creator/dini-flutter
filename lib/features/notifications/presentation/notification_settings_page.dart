import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
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
            context.l10n.text('settings.notifications'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.text('notifications.description')),
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
            decoration: InputDecoration(
              labelText: context.l10n.text('notifications.sound'),
            ),
            items: NotificationSound.values
                .map(
                  (sound) => DropdownMenuItem(
                    value: sound,
                    child: Text(_soundLabel(context, sound)),
                  ),
                )
                .toList(),
            onChanged: (sound) {
              if (sound != null) _update(value.copyWith(sound: sound));
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.text('notifications.friday')),
            value: value.fridayReminder,
            onChanged: (enabled) =>
                _update(value.copyWith(fridayReminder: enabled)),
          ),
          SwitchListTile(
            title: Text(context.l10n.text('notifications.suhoor')),
            value: value.ramadanSuhoorReminder,
            onChanged: (enabled) =>
                _update(value.copyWith(ramadanSuhoorReminder: enabled)),
          ),
          SwitchListTile(
            title: Text(context.l10n.text('notifications.iftar')),
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
                  ? context.l10n.text('notifications.permissionDone')
                  : context.l10n.text('notifications.managePermission'),
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.text('notifications.notice')),
        ],
      ),
    );
  }

  Future<void> _requestPermission() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('notifications.permissionTitle')),
        content: Text(context.l10n.text('notifications.description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('notifications.notNow')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('notifications.continue')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_permissionLabel(context, status))),
      );
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

  String _soundLabel(BuildContext context, NotificationSound sound) =>
      switch (sound) {
        NotificationSound.defaultSound => context.l10n.text(
          'notifications.defaultSound',
        ),
        NotificationSound.bundled => context.l10n.text(
          'notifications.bundledSound',
        ),
        NotificationSound.silent => context.l10n.text('notifications.silent'),
      };
  String _permissionLabel(
    BuildContext context,
    NotificationPermissionStatus status,
  ) => switch (status) {
    NotificationPermissionStatus.granted => context.l10n.text(
      'notifications.granted',
    ),
    NotificationPermissionStatus.denied => context.l10n.text(
      'notifications.denied',
    ),
    NotificationPermissionStatus.permanentlyDenied => context.l10n.text(
      'notifications.permanentlyDenied',
    ),
    NotificationPermissionStatus.unknown => context.l10n.text(
      'notifications.unknown',
    ),
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
            title: Text(context.l10n.prayer(prayer.name)),
            value: value.enabled,
            onChanged: (enabled) => onChanged(value.copyWith(enabled: enabled)),
          ),
          DropdownButtonFormField<int?>(
            initialValue: value.reminderMinutes,
            decoration: InputDecoration(
              labelText: context.l10n.text('notifications.advance'),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(context.l10n.text('notifications.none')),
              ),
              for (final minutes in [5, 10, 15, 30])
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    context.l10n.text('notifications.minutes', {
                      'minutes': minutes,
                    }),
                  ),
                ),
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
}
