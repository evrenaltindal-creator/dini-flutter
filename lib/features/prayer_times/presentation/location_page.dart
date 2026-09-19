import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../domain/city.dart';
import '../domain/location_resolver.dart';
import 'providers.dart';
import 'save_settings.dart';

/// Konum seçimi: cihazdan otomatik ya da listeden şehir.
///
/// Bu ekran açılana kadar konum hiçbir yerden ayarlanamıyordu ve kullanıcı
/// nerede olursa olsun İstanbul'un vaktini görüyordu.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  final _controller = TextEditingController();

  /// Otomatik konum sürerken düğme tekrar basılmamalı.
  bool _locating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation() async {
    setState(() => _locating = true);
    final l10n = context.l10n;
    final resolver = await ref.read(locationResolverProvider.future);
    final result = await resolver.resolveAutomatic();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.isResolved) {
      _say(
        l10n.text(
          result.outcome == LocationOutcome.permissionDenied
              ? 'location.permissionDenied'
              : 'location.unavailable',
        ),
      );
      return;
    }
    await _save(result.preference!.city, result);
  }

  Future<void> _selectCity(City city) async {
    final preference = LocationResolver.fromCity(city);
    await _save(
      city.name,
      LocationResult(LocationOutcome.resolved, preference),
    );
  }

  Future<void> _save(String? name, LocationResult result) async {
    final l10n = context.l10n;
    final settings = ref.read(effectivePrayerSettingsProvider);
    await savePrayerSettings(
      ref,
      settings.copyWith(location: result.preference),
    );
    if (!mounted) return;
    _say(l10n.text('location.saved', {'city': name ?? ''}));
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(effectivePrayerSettingsProvider);
    final directory = ref.watch(cityDirectoryProvider);

    return BackdropScaffold(
      title: l10n.text('location.title'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text('location.current', {
                      'city':
                          settings.location.city ??
                          l10n.text('location.unknown'),
                    }),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.text('location.privacy'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _locating ? null : _useDeviceLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      l10n.text(
                        _locating ? 'location.locating' : 'location.useDevice',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.text('location.search'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: directory.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                // Liste okunamasa bile ekran açılır; kullanıcı otomatik
                // konumu yine de kullanabilir.
                error: (_, _) =>
                    Center(child: Text(l10n.text('location.listUnavailable'))),
                data: (value) {
                  final results = value.search(_controller.text);
                  if (results.isEmpty) {
                    return Center(child: Text(l10n.text('location.noMatch')));
                  }
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final city = results[index];
                      final selected = settings.location.city == city.name;
                      return ListTile(
                        title: Text(city.name),
                        subtitle: Text(city.timezoneId),
                        trailing: selected
                            ? const Icon(Icons.check)
                            : Text(city.country),
                        selected: selected,
                        onTap: () => _selectCity(city),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
