import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/mosque_scene_state.dart';

class MosqueScene extends StatefulWidget {
  final MosqueSceneState state;
  final double height;
  final BorderRadius borderRadius;

  const MosqueScene({
    required this.state,
    this.height = 560,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    super.key,
  });

  @override
  State<MosqueScene> createState() => _MosqueSceneState();
}

class _MosqueSceneState extends State<MosqueScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late double _fromSunProgress;
  late double _toSunProgress;

  @override
  void initState() {
    super.initState();
    _fromSunProgress = 0;
    _toSunProgress = widget.state.sunProgress;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant MosqueScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.sunProgress != widget.state.sunProgress ||
        oldWidget.state.period != widget.state.period) {
      _fromSunProgress = oldWidget.state.sunProgress;
      _toSunProgress = widget.state.sunProgress;
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final asset = _assetFor(widget.state.period);

    return Semantics(
      label: 'Günün saatine göre canlanan cami, güneş ve ay sahnesi',
      container: true,
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: const [
              BoxShadow(
                blurRadius: 28,
                offset: Offset(0, 12),
                color: Color(0x33030D13),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) {
                final motion = reduced
                    ? 1.0
                    : Curves.easeOutCubic.transform(_entrance.value);
                final sunProgress =
                    _fromSunProgress +
                    (_toSunProgress - _fromSunProgress) * motion;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 1100),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Image.asset(
                        asset,
                        key: ValueKey(asset),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x16000000),
                            Colors.transparent,
                            Color(0x42020B0D),
                          ],
                          stops: [0, .55, 1],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _CelestialPainter(
                        state: widget.state,
                        sunProgress: sunProgress,
                        entranceProgress: motion,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _assetFor(MosqueScenePeriod period) => switch (period) {
    MosqueScenePeriod.preFajrNight ||
    MosqueScenePeriod.ishaNight => 'assets/scenes/mosque_night.png',
    MosqueScenePeriod.fajr ||
    MosqueScenePeriod.sunrise ||
    MosqueScenePeriod.maghrib => 'assets/scenes/mosque_dawn.png',
    MosqueScenePeriod.asr ||
    MosqueScenePeriod.goldenHour => 'assets/scenes/mosque_asr.png',
    MosqueScenePeriod.day ||
    MosqueScenePeriod.dhuhr => 'assets/scenes/mosque_day.png',
  };
}

class _CelestialPainter extends CustomPainter {
  final MosqueSceneState state;
  final double sunProgress;
  final double entranceProgress;

  const _CelestialPainter({
    required this.state,
    required this.sunProgress,
    required this.entranceProgress,
  });

  bool get _night =>
      state.period == MosqueScenePeriod.preFajrNight ||
      state.period == MosqueScenePeriod.ishaNight;

  @override
  void paint(Canvas canvas, Size size) {
    if (_night) {
      _paintMoon(canvas, size);
      return;
    }
    _paintSun(canvas, size);
    if (state.moonVisibility > 0) _paintMoon(canvas, size);
  }

  void _paintSun(Canvas canvas, Size size) {
    final progress = sunProgress.clamp(0.0, 1.0);
    final x = size.width * (.08 + .84 * progress);
    final y = size.height * (.39 - .30 * math.sin(math.pi * progress));
    final center = Offset(x, y);
    final visibility = state.period == MosqueScenePeriod.fajr
        ? entranceProgress * .35
        : entranceProgress;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF7C7).withValues(alpha: .72 * visibility),
          const Color(0xFFFFC65C).withValues(alpha: .30 * visibility),
          const Color(0x00FFB24B),
        ],
        stops: const [0, .22, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 78));
    canvas.drawCircle(center, 78, glow);

    final disk = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .98 * visibility),
          const Color(0xFFFFE08A).withValues(alpha: .98 * visibility),
          const Color(0xFFFFB443).withValues(alpha: .9 * visibility),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 13));
    canvas.drawCircle(center, 13, disk);
  }

  void _paintMoon(Canvas canvas, Size size) {
    final reveal = Curves.easeOut.transform(entranceProgress);
    final x = size.width * (.22 + .36 * reveal);
    final y = size.height * (.25 - .08 * math.sin(math.pi * reveal));
    final center = Offset(x, y);
    final opacity = (state.moonVisibility * reveal).clamp(0.0, 1.0);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEAF5FF).withValues(alpha: .34 * opacity),
          const Color(0x006CB4E6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 66));
    canvas.drawCircle(center, 66, glow);

    final outer = Path()..addOval(Rect.fromCircle(center: center, radius: 18));
    final inner = Path()
      ..addOval(Rect.fromCircle(center: center.translate(7, -3), radius: 17));
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    final moon = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .98 * opacity),
          const Color(0xFFC9DCEC).withValues(alpha: .9 * opacity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 18));
    canvas.drawPath(crescent, moon);
  }

  @override
  bool shouldRepaint(covariant _CelestialPainter oldDelegate) =>
      oldDelegate.state.period != state.period ||
      oldDelegate.sunProgress != sunProgress ||
      oldDelegate.entranceProgress != entranceProgress ||
      oldDelegate.state.moonVisibility != state.moonVisibility;
}
