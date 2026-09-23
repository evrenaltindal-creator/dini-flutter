import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kuran sayfasının renkleri: Mushaf kâğıdı, mürekkep, tezhip altını ve
/// tezhip yeşili.
///
/// Uygulama koyu temayla çizilir; kâğıdın üstündeki her yazının rengi bu
/// yüzden buradan açıkça verilir (takvim yaprağındaki gibi).
abstract final class QuranPalette {
  static const paper = Color(0xFFF6EDD8);
  static const paperEdge = Color(0xFFE9DBB8);
  static const ink = Color(0xFF1C1A16);
  static const mutedInk = Color(0xFF5E564A);
  static const gold = Color(0xFFB88A2E);
  static const goldLight = Color(0xFFE2C275);
  static const green = Color(0xFF0F4A3C);
  static const greenDeep = Color(0xFF0A3329);
  static const cream = Color(0xFFF8EFD9);
}

/// Mushaf metninin yazı tipi: âyet sonu işaretini (۝ + rakam) tek bir
/// süslü yuvarlak olarak çizer.
const quranTextFamily = 'AmiriQuran';

/// Sûre başlıklarının yazı tipi.
const quranTitleFamily = 'Amiri';

/// Arap-Hint rakamları: Mushaf'ta âyet numaraları böyle yazılır.
String arabicDigits(int value) => value
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

/// Âyet sonu işareti: U+06DD ve ardından Arap-Hint rakamlarıyla numara.
String ayahEnd(int number) => '۝${arabicDigits(number)}';

/// Sekiz köşeli yıldız (Rub'ul-hizb, ۞): iki karenin 45° döndürülüp üst üste
/// konmasıyla çizilir. Madalyonların ve köşe süslerinin temeli.
class RubElHizbPainter extends CustomPainter {
  final Color stroke;
  final Color? fill;
  final double strokeWidth;

  /// Ortadaki halka; numara yazılacaksa açılır.
  final bool ring;

  const RubElHizbPainter({
    required this.stroke,
    this.fill,
    this.strokeWidth = 1.4,
    this.ring = false,
  });

  Path _star(Offset center, double radius) {
    final path = Path();
    for (final turn in [0.0, math.pi / 4]) {
      final square = Path();
      for (var i = 0; i < 4; i++) {
        final angle = turn + i * math.pi / 2 + math.pi / 4;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        i == 0
            ? square.moveTo(point.dx, point.dy)
            : square.lineTo(point.dx, point.dy);
      }
      square.close();
      path.addPath(square, Offset.zero);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final star = _star(center, radius);
    if (fill != null) canvas.drawPath(star, Paint()..color = fill!);
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(star, line);
    // İç içe ikinci yıldız: tezhipteki çift hat.
    canvas.drawPath(
      _star(center, radius * .78),
      line..strokeWidth = strokeWidth * .6,
    );
    if (ring) {
      canvas.drawCircle(center, radius * .52, line..strokeWidth = strokeWidth);
    }
  }

  @override
  bool shouldRepaint(RubElHizbPainter old) =>
      old.stroke != stroke || old.fill != fill || old.ring != ring;
}

/// Yıldız madalyon içinde numara: sûre listesinde ve meal kipinde âyet
/// numarası.
class StarMedallion extends StatelessWidget {
  final String label;
  final double size;
  final Color stroke;
  final Color fill;
  final Color text;

  const StarMedallion({
    super.key,
    required this.label,
    this.size = 44,
    this.stroke = QuranPalette.gold,
    this.fill = QuranPalette.cream,
    this.text = QuranPalette.green,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: RubElHizbPainter(stroke: stroke, fill: fill, ring: true),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: size * (label.length > 2 ? .26 : .32),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// Mushaf sayfasının tezhipli çerçevesi.
///
/// Kâğıt zemin, dışta kalın ve içte ince iki altın hat, aralarında
/// baklava dizisi ve dört köşede yıldız rozet.
class MushafFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MushafFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(26, 26, 26, 26),
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const RadialGradient(
        radius: 1.1,
        colors: [QuranPalette.paper, QuranPalette.paperEdge],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: CustomPaint(
      foregroundPainter: const _FramePainter(),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = QuranPalette.gold
      ..style = PaintingStyle.stroke;
    final outer = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final inner = outer.deflate(9);
    canvas.drawRect(outer, gold..strokeWidth = 2.2);
    canvas.drawRect(inner, gold..strokeWidth = 1);

    // İki hat arasında baklava dizisi.
    final band = Paint()..color = QuranPalette.goldLight;
    const step = 11.0;
    void diamonds(Offset from, Offset to) {
      final length = (to - from).distance;
      final direction = (to - from) / length;
      for (var d = 14.0; d < length - 14; d += step) {
        final c = from + direction * d;
        final path = Path()
          ..moveTo(c.dx, c.dy - 2.6)
          ..lineTo(c.dx + 2.6, c.dy)
          ..lineTo(c.dx, c.dy + 2.6)
          ..lineTo(c.dx - 2.6, c.dy)
          ..close();
        canvas.drawPath(path, band);
      }
    }

    final mid = outer.deflate(4.5);
    diamonds(mid.topLeft, mid.topRight);
    diamonds(mid.bottomLeft, mid.bottomRight);
    diamonds(mid.topLeft, mid.bottomLeft);
    diamonds(mid.topRight, mid.bottomRight);

    // Köşe rozetleri.
    for (final corner in [
      mid.topLeft,
      mid.topRight,
      mid.bottomLeft,
      mid.bottomRight,
    ]) {
      canvas.save();
      canvas.translate(corner.dx - 11, corner.dy - 11);
      const RubElHizbPainter(
        stroke: QuranPalette.gold,
        fill: QuranPalette.green,
        strokeWidth: 1.2,
      ).paint(canvas, const Size(22, 22));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}

/// Sûre başlığı: iki ucu sivri, yeşil zeminli, altın çerçeveli kartuş;
/// ortada sûrenin Arapça adı, iki yanda yıldız madalyon.
class SurahHeader extends StatelessWidget {
  /// "سورة الفاتحة"
  final String arabicName;

  /// "Fâtiha Sûresi · Mekkî · 7 âyet"
  final String caption;

  const SurahHeader({
    super.key,
    required this.arabicName,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 64,
        child: CustomPaint(
          painter: const _CartouchePainter(),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const _SideStar(),
              Expanded(
                child: Text(
                  arabicName,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: quranTitleFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1.2,
                    color: QuranPalette.goldLight,
                  ),
                ),
              ),
              const _SideStar(),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        caption,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: QuranPalette.mutedInk,
          fontSize: 13,
          letterSpacing: .4,
        ),
      ),
    ],
  );
}

class _SideStar extends StatelessWidget {
  const _SideStar();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 30,
    child: CustomPaint(
      painter: RubElHizbPainter(
        stroke: QuranPalette.goldLight,
        fill: QuranPalette.greenDeep,
        strokeWidth: 1.2,
      ),
    ),
  );
}

class _CartouchePainter extends CustomPainter {
  const _CartouchePainter();

  Path _shape(Rect r, double tip) => Path()
    ..moveTo(r.left, r.center.dy)
    ..lineTo(r.left + tip, r.top)
    ..lineTo(r.right - tip, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.right - tip, r.bottom)
    ..lineTo(r.left + tip, r.bottom)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = _shape(rect.deflate(1), 22);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [QuranPalette.green, QuranPalette.greenDeep],
        ).createShader(rect),
    );
    final gold = Paint()
      ..color = QuranPalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(outer, gold);
    canvas.drawPath(
      _shape(rect.deflate(6), 18),
      gold
        ..strokeWidth = .8
        ..color = QuranPalette.goldLight,
    );
  }

  @override
  bool shouldRepaint(_CartouchePainter old) => false;
}

/// Sûre başındaki Besmele.
class BasmalaLine extends StatelessWidget {
  final String text;

  const BasmalaLine({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        fontFamily: quranTextFamily,
        fontSize: 28,
        height: 1.9,
        color: QuranPalette.ink,
      ),
    ),
  );
}

/// Mushaf kipi: âyetler kesintisiz akar, aralarında âyet sonu işareti.
class MushafText extends StatelessWidget {
  /// (numara, metin)
  final List<(int, String)> ayahs;
  final double fontSize;

  const MushafText({super.key, required this.ayahs, this.fontSize = 27});

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final (number, text) in ayahs) ...[
          TextSpan(text: '$text '),
          TextSpan(
            text: '${ayahEnd(number)} ',
            style: const TextStyle(color: QuranPalette.gold),
          ),
        ],
      ],
    ),
    textAlign: TextAlign.justify,
    textDirection: TextDirection.rtl,
    style: TextStyle(
      fontFamily: quranTextFamily,
      fontSize: fontSize,
      height: 2.05,
      color: QuranPalette.ink,
    ),
  );
}

/// Meal kipi: âyet, altında kullanıcının dilinde meali.
class AyahWithTranslation extends StatelessWidget {
  final int number;
  final String arabic;
  final String translation;
  final String numberLabel;

  const AyahWithTranslation({
    super.key,
    required this.number,
    required this.arabic,
    required this.translation,
    required this.numberLabel,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$arabic ${ayahEnd(number)}',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: quranTextFamily,
            fontSize: 26,
            height: 2,
            color: QuranPalette.ink,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarMedallion(label: numberLabel, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                translation,
                style: const TextStyle(
                  color: QuranPalette.ink,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Divider(),
      ],
    ),
  );
}

/// Âyetler arası ince altın ayraç, ortasında küçük yıldız.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: QuranPalette.goldLight, thickness: .8)),
      SizedBox(width: 6),
      SizedBox.square(
        dimension: 12,
        child: CustomPaint(
          painter: RubElHizbPainter(
            stroke: QuranPalette.gold,
            fill: QuranPalette.goldLight,
            strokeWidth: .8,
          ),
        ),
      ),
      SizedBox(width: 6),
      Expanded(child: Divider(color: QuranPalette.goldLight, thickness: .8)),
    ],
  );
}
