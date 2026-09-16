import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../prayer_times/domain/prayer_engine.dart';
import '../../prayer_times/presentation/providers.dart';
import '../data/magnetic_declination.dart';
import '../domain/compass_north.dart';
import '../domain/qibla_calculator.dart';

class QiblaPage extends ConsumerStatefulWidget {
  /// Manyetik sapmayı çözen servis. Testlerde sahte bir servisle
  /// değiştirilebilsin diye dışarıdan verilebilir; verilmezse platforma
  /// bağlı olan gerçek servis kullanılır.
  final MagneticDeclinationService? declinationService;

  const QiblaPage({super.key, this.declinationService});

  @override
  ConsumerState<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends ConsumerState<QiblaPage> {
  StreamSubscription<CompassEvent>? _subscription;
  double? _heading;

  /// Okun birikimli dönüşü. Ham fark ±180 sınırında işaret değiştirdiği için
  /// doğrudan animasyona verilemez; bkz. [QiblaNeedle].
  QiblaNeedle _needle = const QiblaNeedle();

  /// Pusula okumasının gerçek kuzeye çevrimi. Sapma çözülene kadar
  /// düzeltmesiz başlar; Android'de sapma birkaç derecedir, iOS'ta sıfırdır.
  CompassNorth _north = const CompassNorth(readingIsTrueNorth: false);

  @override
  void initState() {
    super.initState();
    _resolveNorth();
    _subscription = FlutterCompass.events?.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          // Android manyetik kuzeye göre ölçer; kıble açısı gerçek kuzeye
          // göredir. Karşılaştırmadan önce okuma çevrilir.
          final heading = event.heading == null
              ? null
              : _north.toTrue(event.heading!);
          _heading = heading;
          if (heading != null) {
            _needle = _needle.update(
              const QiblaCalculator().turnDifference(
                bearing: _bearing,
                heading: heading,
              ),
            );
          }
        });
      },
      onError: (_) {
        if (mounted) setState(() => _heading = null);
      },
    );
  }

  /// Yerel manyetik sapmayı çözer ve oku yeniden hizalar.
  Future<void> _resolveNorth() async {
    final service = widget.declinationService ?? MagneticDeclinationService();
    final north = await service.resolve(_coordinates);
    if (mounted) setState(() => _north = north);
  }

  Coordinates get _coordinates {
    final settings = ref.read(effectivePrayerSettingsProvider);
    return Coordinates(
      settings.location.latitude ?? 41.0082,
      settings.location.longitude ?? 28.9784,
    );
  }

  /// Kıble açısı, kullanıcının kayıtlı koordinatlarından hesaplanır.
  double get _bearing {
    final settings = ref.read(effectivePrayerSettingsProvider);
    return const QiblaCalculator().bearing(
      Coordinates(
        settings.location.latitude ?? 41.0082,
        settings.location.longitude ?? 28.9784,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(effectivePrayerSettingsProvider);
    const calculator = QiblaCalculator();
    final bearing = calculator.bearing(
      Coordinates(
        settings.location.latitude ?? 41.0082,
        settings.location.longitude ?? 28.9784,
      ),
    );
    // Metin ve hizalama anlık farkı kullanır; animasyon ise birikimli dönüşü.

    final difference = _heading == null
        ? null
        : calculator.turnDifference(bearing: bearing, heading: _heading!);
    final aligned = difference != null && difference.abs() < 4;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('home.qibla'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 28),
          children: [
            Text(
              context.l10n.text('qibla.title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedRotation(
                turns: _needle.turns,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: _CompassFace(aligned: aligned),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: aligned
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(18),
                child: Column(
                  children: [
                    Text(
                      difference == null
                          ? context.l10n.text('qibla.sensorUnavailable')
                          : aligned
                          ? context.l10n.text('qibla.ready')
                          : context.l10n.text(
                              difference > 0
                                  ? 'qibla.turnRight'
                                  : 'qibla.turnLeft',
                              {'degrees': difference.abs().round()},
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.text('qibla.bearings', {
                        'heading': _heading?.round() ?? '—',
                        'qibla': bearing.round(),
                      }),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    // Hangi kuzeye göre ölçtüğümüzü söylemek gerekir:
                    // basılı çizelgelerdeki kıble açısı manyetik pusulaya
                    // göre olabilir ve birkaç derece farklı görünür.
                    Text(
                      _north.isKnown && !_north.readingIsTrueNorth
                          ? context.l10n.text('qibla.northBoth', {
                              'true': bearing.round(),
                              'magnetic': _north.toMagnetic(bearing).round(),
                            })
                          : context.l10n.text('qibla.northTrue'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.screen_rotation_outlined),
              title: Text(context.l10n.text('qibla.calibration')),
              subtitle: Text(context.l10n.text('qibla.calibrationHint')),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.text('qibla.privacy'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassFace extends StatelessWidget {
  final bool aligned;

  const _CompassFace({required this.aligned});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        border: Border.all(
          color: aligned ? scheme.secondary : scheme.primary,
          width: aligned ? 5 : 2,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 28,
            color: Color(0x24000000),
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 15,
            child: Column(
              children: [
                Icon(Icons.mosque, color: scheme.secondary, size: 34),
                Icon(Icons.arrow_drop_up, color: scheme.secondary, size: 42),
              ],
            ),
          ),
          Icon(
            Icons.navigation,
            size: 86,
            color: aligned ? scheme.secondary : scheme.primary,
          ),
        ],
      ),
    );
  }
}
