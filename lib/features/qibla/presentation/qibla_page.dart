import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/qibla_calculator.dart';
import '../../prayer_times/domain/prayer_engine.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});
  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  StreamSubscription<MagnetometerEvent>? _subscription;
  double? _heading;
  final double _bearing = const QiblaCalculator().bearing(
    const Coordinates(41.0082, 28.9784),
  );

  @override
  void initState() {
    super.initState();
    _subscription = magnetometerEventStream().listen(
      (event) {
        final value =
            (math.atan2(event.y, event.x) * 180 / math.pi + 360) % 360;
        if (mounted) setState(() => _heading = value);
      },
      onError: (_) {
        if (mounted) setState(() => _heading = null);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final difference = _heading == null
        ? null
        : ((_bearing - _heading! + 540) % 360) - 180;
    return Scaffold(
      appBar: AppBar(title: const Text('Kıble')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore, size: 110),
              Text(
                '${_bearing.toStringAsFixed(0)}°',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(
                _heading == null
                    ? 'Pusula sensörü kullanılamıyor. Telefonu düz tutup kalibrasyon hareketini deneyin.'
                    : 'Cihaz yönü: ${_heading!.toStringAsFixed(0)}°${difference!.abs() < 5 ? ' · Hizalı' : ''}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Konum cihazda tutulur; dışarı gönderilmez.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
