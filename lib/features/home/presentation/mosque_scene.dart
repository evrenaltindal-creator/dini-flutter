import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/mosque_scene_state.dart';

class MosqueScene extends StatelessWidget {
  final MosqueSceneState state;
  const MosqueScene({required this.state, super.key});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'Günün saatine göre değişen cami sahnesi',
      container: true,
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(blurRadius: 20, color: Color(0x22000000)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: CustomPaint(
            painter: _MosquePainter(state),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _MosquePainter extends CustomPainter {
  final MosqueSceneState state;
  const _MosquePainter(this.state);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final night =
        state.period == MosqueScenePeriod.preFajrNight ||
        state.period == MosqueScenePeriod.ishaNight;
    final sky = night
        ? const [Color(0xff07152d), Color(0xff1e3154)]
        : state.period == MosqueScenePeriod.goldenHour ||
              state.period == MosqueScenePeriod.maghrib
        ? const [Color(0xffc76658), Color(0xffffc77d)]
        : const [Color(0xff377aa1), Color(0xffd4eff0)];
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: sky,
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
    p.shader = null;
    final star = Paint()
      ..color = Colors.white.withValues(alpha: state.starVisibility);
    for (var n = 0; n < 14; n++) {
      final x = (n * 83 % size.width);
      final y = 20.0 + (n * 37 % 90).toDouble();
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 1.4, star);
    }
    final sunPaint = Paint()
      ..color = (night ? const Color(0xfff4f1d0) : const Color(0xffffd36b))
          .withValues(alpha: night ? state.moonVisibility : 1.0);
    final x = size.width * (0.15 + 0.7 * state.sunProgress);
    final y = night
        ? 54.0
        : 150.0 -
              110.0 *
                  math.sin(math.pi * state.sunProgress.clamp(0, 1).toDouble());
    canvas.drawCircle(Offset(x, y), night ? 22 : 20, sunPaint);
    final atmosphere = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: night ? .04 : .16),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .38, size.width, size.height * .62),
      atmosphere,
    );
    final ground = Paint()
      ..color = const Color(0xff101d2d)
          .withValues(alpha: state.foregroundBrightness);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height - 58)
      ..quadraticBezierTo(
        size.width * .5,
        size.height - 82,
        size.width,
        size.height - 52,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, ground);
    final mosque = Paint()..color = const Color(0xff122238);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .18, size.height - 100, size.width * .64, 100),
      mosque,
    );
    canvas.drawCircle(Offset(size.width * .5, size.height - 102), 34, mosque);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .49, size.height - 164, 4, 62),
      mosque,
    );
    for (final mx in [size.width * .24, size.width * .76]) {
      canvas.drawRect(Rect.fromLTWH(mx, size.height - 155, 10, 155), mosque);
      canvas.drawCircle(Offset(mx + 5, size.height - 158), 8, mosque);
    }
    final window = Paint()
      ..color = Color.lerp(
        const Color(0xffd6e7ef),
        const Color(0xffffd36b),
        state.mosqueLightingLevel,
      )!;
    for (var n = 0; n < 5; n++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .29 + n * 32.0, size.height - 58, 14, 28),
          const Radius.circular(7),
        ),
        window,
      );
    }
    if (state.friday) {
      final accent = Paint()
        ..color = const Color(0xffdfb76a).withValues(alpha: .8);
      canvas.drawCircle(Offset(size.width * .5, 24), 4, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _MosquePainter old) =>
      old.state.period != state.period ||
      old.state.sunProgress != state.sunProgress ||
      old.state.friday != state.friday ||
      old.state.ramadan != state.ramadan;
}
