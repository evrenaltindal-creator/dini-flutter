import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../domain/guided_prayer.dart';

/// Namaz hocasının ekranda gösterdiği kişi: yandan, kıbleye (sağa) dönük.
///
/// Duruşlar eklem açılarıyla tanımlanır; iki duruş arasında açılar
/// yumuşakça değiştirilir, böylece figür tekbirden kıyama, rükûdan secdeye
/// gerçekten "hareket eder". Uzuvların boyu sabittir, açı ne olursa olsun
/// kol ve bacak uzayıp kısalmaz.
class PrayerFigure extends StatelessWidget {
  final PrayerPosture posture;
  final String semanticLabel;

  const PrayerFigure({
    super.key,
    required this.posture,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: TweenAnimationBuilder<FigurePose>(
        tween: _PoseTween(end: FigurePose.of(posture)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        builder: (context, pose, _) => CustomPaint(
          painter: FigurePainter(
            pose: pose,
            body: scheme.primary,
            mat: scheme.primaryContainer,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PoseTween extends Tween<FigurePose> {
  _PoseTween({required FigurePose end}) : super(begin: end, end: end);

  @override
  FigurePose lerp(double t) => FigurePose.lerp(begin!, end!, t);
}

/// Bir duruşun eklem açıları (radyan, ekranda: 0 = ileri/sağa, π/2 = aşağı).
///
/// Konumlar birim karede verilir: genişlik ve yükseklik 1, zemin
/// [FigurePose.ground] hizasında.
@immutable
class FigurePose {
  final double hipX;
  final double hipY;
  final double torso;
  final double head;
  final double upperArm;
  final double forearm;
  final double thigh;
  final double shin;
  final double foot;

  /// Yüzün hangi yöne baktığı: 1 kıbleye, 0 izleyene (sağa selâm),
  /// -1 izleyenin tersine (sola selâm).
  final double facing;

  const FigurePose({
    required this.hipX,
    required this.hipY,
    required this.torso,
    required this.head,
    required this.upperArm,
    required this.forearm,
    required this.thigh,
    required this.shin,
    required this.foot,
    this.facing = 1,
  });

  static const ground = .88;

  static const torsoLength = .27;
  static const neckLength = .04;
  static const headRadius = .05;
  static const upperArmLength = .15;
  static const forearmLength = .14;
  static const thighLength = .18;
  static const shinLength = .17;
  static const footLength = .07;

  static const _down = math.pi / 2;
  static const _up = -math.pi / 2;

  static const upright = FigurePose(
    hipX: .5,
    hipY: .53,
    torso: _up,
    head: _up,
    upperArm: _down,
    forearm: _down,
    thigh: _down,
    shin: _down,
    foot: 0,
  );

  /// Kıyam: eller önde bağlı.
  static const standing = FigurePose(
    hipX: .5,
    hipY: .53,
    torso: _up,
    head: _up,
    upperArm: _down + .2,
    forearm: .1,
    thigh: _down,
    shin: _down,
    foot: 0,
  );

  /// Tekbir: eller kulak hizasında.
  static const takbir = FigurePose(
    hipX: .5,
    hipY: .53,
    torso: _up,
    head: _up,
    upperArm: .6,
    forearm: -1.9,
    thigh: _down,
    shin: _down,
    foot: 0,
  );

  /// Rükû: sırt yere paralel, eller dizlerde.
  static const bowing = FigurePose(
    hipX: .40,
    hipY: .53,
    torso: -.03,
    head: .15,
    upperArm: 2.55,
    forearm: 2.45,
    thigh: _down,
    shin: _down,
    foot: 0,
  );

  /// Secde: dizler, eller, alın ve burun yerde; dirsekler yerden kalkık.
  static const prostrating = FigurePose(
    hipX: .40,
    hipY: .70,
    torso: .33,
    head: .62,
    upperArm: .2,
    forearm: 2.67,
    thigh: _down,
    shin: math.pi + .2,
    foot: _down + .5,
  );

  /// Oturuş: topuklar üzerinde, eller uyluklarda.
  static const sitting = FigurePose(
    hipX: .43,
    hipY: .83,
    torso: _up,
    head: -1.45,
    upperArm: 1.25,
    forearm: 1.1,
    thigh: .286,
    shin: math.pi,
    foot: math.pi - .1,
  );

  static FigurePose of(PrayerPosture posture) => switch (posture) {
    PrayerPosture.upright => upright,
    PrayerPosture.takbir => takbir,
    PrayerPosture.standing => standing,
    PrayerPosture.bowing => bowing,
    PrayerPosture.prostrating => prostrating,
    PrayerPosture.sitting => sitting,
    PrayerPosture.salamRight => sitting.withFacing(0),
    PrayerPosture.salamLeft => sitting.withFacing(-1),
  };

  FigurePose withFacing(double value) => FigurePose(
    hipX: hipX,
    hipY: hipY,
    torso: torso,
    head: head,
    upperArm: upperArm,
    forearm: forearm,
    thigh: thigh,
    shin: shin,
    foot: foot,
    facing: value,
  );

  static FigurePose lerp(FigurePose a, FigurePose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return FigurePose(
      hipX: l(a.hipX, b.hipX),
      hipY: l(a.hipY, b.hipY),
      torso: l(a.torso, b.torso),
      head: l(a.head, b.head),
      upperArm: l(a.upperArm, b.upperArm),
      forearm: l(a.forearm, b.forearm),
      thigh: l(a.thigh, b.thigh),
      shin: l(a.shin, b.shin),
      foot: l(a.foot, b.foot),
      facing: l(a.facing, b.facing),
    );
  }

  // Aynı duruşu yeniden vermek canlandırmayı baştan başlatmasın.
  @override
  bool operator ==(Object other) =>
      other is FigurePose &&
      other.hipX == hipX &&
      other.hipY == hipY &&
      other.torso == torso &&
      other.head == head &&
      other.upperArm == upperArm &&
      other.forearm == forearm &&
      other.thigh == thigh &&
      other.shin == shin &&
      other.foot == foot &&
      other.facing == facing;

  @override
  int get hashCode => Object.hash(
    hipX,
    hipY,
    torso,
    head,
    upperArm,
    forearm,
    thigh,
    shin,
    foot,
    facing,
  );

  /// Eklemlerin birim karedeki yerleri.
  FigureJoints get joints {
    Offset along(Offset from, double angle, double length) =>
        from + Offset(math.cos(angle), math.sin(angle)) * length;
    final hip = Offset(hipX, hipY);
    final shoulder = along(hip, torso, torsoLength);
    final neck = along(shoulder, head, neckLength);
    final headCenter = along(neck, head, headRadius);
    final elbow = along(shoulder, upperArm, upperArmLength);
    final hand = along(elbow, forearm, forearmLength);
    final knee = along(hip, thigh, thighLength);
    final ankle = along(knee, shin, shinLength);
    final toe = along(ankle, foot, footLength);
    return FigureJoints(
      hip: hip,
      shoulder: shoulder,
      neck: neck,
      head: headCenter,
      elbow: elbow,
      hand: hand,
      knee: knee,
      ankle: ankle,
      toe: toe,
    );
  }
}

@immutable
class FigureJoints {
  final Offset hip;
  final Offset shoulder;
  final Offset neck;
  final Offset head;
  final Offset elbow;
  final Offset hand;
  final Offset knee;
  final Offset ankle;
  final Offset toe;

  const FigureJoints({
    required this.hip,
    required this.shoulder,
    required this.neck,
    required this.head,
    required this.elbow,
    required this.hand,
    required this.knee,
    required this.ankle,
    required this.toe,
  });
}

class FigurePainter extends CustomPainter {
  final FigurePose pose;
  final Color body;
  final Color mat;

  const FigurePainter({
    required this.pose,
    required this.body,
    required this.mat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Figür kare bir alanda çizilir ve ortalanır.
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    Offset p(Offset unit) => unit * side;

    // Seccade.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          .1 * side,
          FigurePose.ground * side,
          .92 * side,
          (FigurePose.ground + .035) * side,
        ),
        Radius.circular(.012 * side),
      ),
      Paint()..color = mat,
    );

    final j = pose.joints;
    final limb = Paint()
      ..color = body
      ..strokeWidth = .05 * side
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final torso = Paint()
      ..color = body
      ..strokeWidth = .085 * side
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void chain(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(p(points.first).dx, p(points.first).dy);
      for (final point in points.skip(1)) {
        path.lineTo(p(point).dx, p(point).dy);
      }
      canvas.drawPath(path, paint);
    }

    chain([j.hip, j.knee, j.ankle, j.toe], limb);
    chain([j.hip, j.shoulder], torso);
    chain([j.shoulder, j.neck], limb);
    chain([j.shoulder, j.elbow, j.hand], limb);
    canvas.drawCircle(
      p(j.head),
      FigurePose.headRadius * side,
      Paint()..color = body,
    );

    // Yüzün yönü: kıbleye dönükken göz önde; sağa selâmda izleyene döner,
    // sola selâmda arkaya döner ve göz görünmez.
    if (pose.facing > -.5) {
      final forward = Offset(
        math.cos(pose.head + math.pi / 2),
        math.sin(pose.head + math.pi / 2),
      );
      final eye =
          j.head +
          forward * (FigurePose.headRadius * .45 * pose.facing.clamp(0, 1)) +
          Offset(0, -FigurePose.headRadius * .1);
      canvas.drawCircle(
        p(eye),
        .011 * side,
        Paint()..color = mat.withValues(alpha: 1),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.pose != pose || old.body != body || old.mat != mat;
}
