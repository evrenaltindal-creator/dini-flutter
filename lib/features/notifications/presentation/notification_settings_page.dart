import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../../prayer_times/presentation/providers.dart';
import '../../../shared/models/domain.dart';
import '../data/notification_preferences_repository.dart';
import '../data/flutter_local_notification_service.dart';
import '../data/notification_scheduler.dart';
import '../domain/notification_system.dart';
import '../../onboarding/data/system_settings.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => BackdropScaffold(
    title: context.l10n.text('settings.notifications'),
    body: const SafeArea(child: NotificationSettingsView()),
  );
}

class NotificationSettingsView extends ConsumerStatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  ConsumerState<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState
    extends ConsumerState<NotificationSettingsView> {
  late final NotificationPreferencesRepository repository;
  late final LocalNotificationService service;
  NotificationPreferences? preferences;
  bool permissionRequested = false;

  /// Tam zamanlı alarm izni. Kapalıyken bildirimler birkaç dakika gecikir;
  /// kullanıcı bunu bilmeli ve açabilmeli.
  ExactAlarmPermission exactAlarms = ExactAlarmPermission.unknown;
  @override
  void initState() {
    super.initState();
    repository = NotificationPreferencesRepository(
      ref.read(localStorageProvider),
    );
    service = ref.read(notificationServiceProvider);
    service.initialize();
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    final exact = await _readExactAlarmPermission();
    if (!mounted) return;
    setState(() {
      preferences = value;
      exactAlarms = exact;
    });
    // Daha önce kaydedilmiş tercihler hiçbir yerde yeniden planlanmıyordu.
    // Ekranı açmak, kayan sekiz günlük pencereyi de tazeler.
    await _reschedule(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = preferences;
    if (value == null) return const Center(child: CircularProgressIndicator());
    final times = ref.watch(prayerTimesProvider);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
      children: [
        Text(context.l10n.text('notifications.description')),
        const SizedBox(height: 16),
        ...notificationPrayers.map(
          (prayer) => _PrayerNotificationTile(
            prayer: prayer,
            time: _formatTime(times.times[prayer]!),
            value: value.forPrayer(prayer),
            onChanged: (next) => _update(
              value.copyWith(prayers: {...value.prayers, prayer: next}),
            ),
          ),
        ),
        DropdownButtonFormField<NotificationSound>(
          // Dar ekran ve büyük yazı ölçeğinde yatay taşmayı önler.
          isExpanded: true,
          initialValue: value.sound,
          decoration: InputDecoration(
            labelText: context.l10n.text('notifications.sound'),
          ),
          items: NotificationSound.values
              .map(
                (sound) => DropdownMenuItem(
                  value: sound,
                  child: Text(
                    _soundLabel(context, sound),
                    overflow: TextOverflow.ellipsis,
                  ),
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
        // Süre yalnızca uyarı açıkken anlamlıdır; kapalıyken göstermek
        // kullanıcıya çalışmayan bir ayar sunmak olur.
        if (value.ramadanSuhoorReminder)
          _MinutesField(
            label: context.l10n.text('notifications.suhoorMinutes'),
            value: value.suhoorMinutes,
            choices: NotificationPreferences.suhoorChoices,
            onChanged: (minutes) =>
                _update(value.copyWith(suhoorMinutes: minutes)),
          ),
        SwitchListTile(
          title: Text(context.l10n.text('notifications.iftar')),
          value: value.ramadanIftarReminder,
          onChanged: (enabled) =>
              _update(value.copyWith(ramadanIftarReminder: enabled)),
        ),
        if (value.ramadanIftarReminder)
          _MinutesField(
            label: context.l10n.text('notifications.iftarMinutes'),
            value: value.iftarMinutes,
            choices: NotificationPreferences.iftarChoices,
            onChanged: (minutes) =>
                _update(value.copyWith(iftarMinutes: minutes)),
          ),
        if (value.ramadanSuhoorReminder || value.ramadanIftarReminder)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 4),
            child: Text(
              context.l10n.text('notifications.ramadanOnly'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
        // İzin kapalıyken bildirimler gecikir. Sessizce geciktirmek yerine
        // durumu söylemek ve açma yolunu göstermek gerekir.
        if (exactAlarms == ExactAlarmPermission.denied)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.text('notifications.exactWarning')),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _requestExactAlarms,
                    icon: const Icon(Icons.alarm_on_outlined),
                    label: Text(context.l10n.text('notifications.exactAllow')),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Tam zamanlı alarm izni verilmiş olsa bile agresif pil yönetimi olan
        // cihazlar uygulamayı uyutur ve bildirim dakikalarca gecikir. Rehber
        // ilk açılışta gösteriliyor; oradan geçen kullanıcı için tek kalıcı
        // yer burasıdır.
        const _BatteryGuide(),
        const SizedBox(height: 8),
        Text(context.l10n.text('notifications.notice')),
      ],
    );
  }

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
    // Planlama izne bağlanmamalı: permissionRequested yalnızca kullanıcı bu
    // oturumda izin düğmesine bastıysa true oluyordu, dolayısıyla açılan bir
    // alarm çoğu zaman hiç kurulmuyordu.
    await _reschedule(next);
  }

  Future<void> _reschedule(NotificationPreferences value) =>
      reschedulePrayerNotifications(
        storage: ref.read(localStorageProvider),
        settings: ref.read(effectivePrayerSettingsProvider),
        preferences: value,
        service: service,
      );

  /// Servis somut türse izin durumunu okur. Sahte servislerde bu kavram yok.
  Future<ExactAlarmPermission> _readExactAlarmPermission() async {
    final concrete = service;
    if (concrete is! FlutterLocalNotificationService) {
      return ExactAlarmPermission.allowed;
    }
    return concrete.refreshExactAlarmPermission();
  }

  Future<void> _requestExactAlarms() async {
    final concrete = service;
    if (concrete is! FlutterLocalNotificationService) return;
    final next = await concrete.requestExactAlarmPermission();
    if (!mounted) return;
    setState(() => exactAlarms = next);
    // İzin verildiyse kip değişti; alarmlar yeni kiple yeniden kurulmalı.
    final value = preferences;
    if (value != null) await _reschedule(value);
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
  final String time;
  final PrayerNotificationPreference value;
  final ValueChanged<PrayerNotificationPreference> onChanged;
  const _PrayerNotificationTile({
    required this.prayer,
    required this.time,
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
            secondary: const Icon(Icons.alarm_outlined),
            title: Text(context.l10n.prayer(prayer.name)),
            subtitle: Text(time),
            value: value.enabled,
            onChanged: (enabled) => onChanged(value.copyWith(enabled: enabled)),
          ),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: value.reminderMinutes,
            decoration: InputDecoration(
              labelText: context.l10n.text('notifications.advance'),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  context.l10n.text('notifications.none'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final minutes in [5, 10, 15, 30])
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    context.l10n.text('notifications.minutes', {
                      'minutes': minutes,
                    }),
                    overflow: TextOverflow.ellipsis,
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

/// Dakika seçimi. Sahur ve iftar uyarılarının kaç dakika önce çalacağını
/// belirler; sıfır "yalnızca vaktinde" demektir.
class _MinutesField extends StatelessWidget {
  final String label;
  final int value;
  final List<int> choices;
  final ValueChanged<int> onChanged;

  const _MinutesField({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Kayıtlı değer listede yoksa (eski sürümden gelen bir ayar) dropdown
    // hata verir; listeye eklenerek gösterilir.
    final items = {...choices, value}.toList()..sort();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map(
              (minutes) => DropdownMenuItem(
                value: minutes,
                child: Text(
                  minutes == 0
                      ? l10n.text('notifications.onlyAtTime')
                      : l10n.text('notifications.minutesBefore', {
                          'minutes': minutes,
                        }),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (minutes) {
          if (minutes != null) onChanged(minutes);
        },
      ),
    );
  }
}

/// Pil optimizasyonu ve otomatik başlatma rehberi.
///
/// Üretici ayar ekranlarının intent'leri belgelenmemiştir ve cihazdan cihaza
/// değişir; doğrudan açmaya çalışmak kırılır. Uygulamanın kendi ayar sayfası
/// her Android sürümünde vardır, pil ayarı oradan ulaşılır. Açılamazsa çökme
/// değil, elle izlenebilir bir yönlendirme gösterilir.
class _BatteryGuide extends ConsumerWidget {
  const _BatteryGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.battery_saver_outlined),
        title: Text(l10n.text('onboarding.battery.title')),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.text('onboarding.battery.body')),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              final opened = await ref
                  .read(systemSettingsProvider)
                  .openAppSettings();
              if (opened || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.text('onboarding.battery.unavailable')),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.text('onboarding.battery.action')),
          ),
        ],
      ),
    );
  }
}
