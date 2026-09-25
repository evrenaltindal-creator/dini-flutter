import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/mahya_geometry.dart';

/// Mahyanın parlaklığı. Arka plan perdesi koyulaştıkça mahya geri çekilir:
/// içerik okunabilirliği her zaman önce gelir.
enum MahyaGlow {
  /// Ana ekran: mahya fotoğrafın parçası gibi tam parlaklıkta yanar.
  full,

  /// Liste ekranları: metnin arkasında hafif bir ışık olarak kalır.
  dim,
}

/// Minareler arasına asılan ışıklı yazı.
///
/// Yazı kabloyla birlikte çizilir; kablo iki şerefe arasında hafifçe sarkar.
/// Harfler tek tek ampul olarak değil, ampul ışığını taklit eden bir parıltı
/// ile çizilir: gerçek ampul dizisi telefon ölçeğinde okunmaz bir noktalar
/// bulutuna dönüşüyor.
class MahyaView extends StatelessWidget {
  /// Ekranda görünecek yazı.
  final String text;

  /// Ekran okuyucunun söyleyeceği cümle.
  final String semanticsLabel;

  final MahyaGlow glow;

  /// Arka plan görselinin gerçek boyutu; minare yerleri buna göre çözülür.
  final Size imageSize;

  const MahyaView({
    required this.text,
    required this.semanticsLabel,
    required this.imageSize,
    this.glow = MahyaGlow.full,
    super.key,
  });

  /// Testlerin mahyayı bulmak için kullandığı anahtar.
  static const viewKey = ValueKey('ramadan-mahya');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: viewKey,
    builder: (context, constraints) {
      final anchors = mahyaAnchors(
        screen: constraints.biggest,
        image: imageSize,
      );
      // Minareler kırpılıp kaldıysa mahya çizilmez; yamuk bir kablo
      // çizmektense hiç çizmemek doğrudur.
      if (anchors == null) return const SizedBox.shrink();
      return Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: CustomPaint(
          size: constraints.biggest,
          painter: MahyaPainter(
            text: text,
            anchors: anchors,
            opacity: glow == MahyaGlow.full ? 1 : .38,
            textDirection: Directionality.of(context),
          ),
        ),
      );
    },
  );
}

/// Kabloyu, asma iplerini ve ışıklı yazıyı çizer.
class MahyaPainter extends CustomPainter {
  final String text;
  final MahyaAnchors anchors;
  final double opacity;
  final TextDirection textDirection;

  const MahyaPainter({
    required this.text,
    required this.anchors,
    required this.opacity,
    required this.textDirection,
  });

  /// Ampul sarısı. Tema renginden bağımsızdır: mahya gece fotoğrafının
  /// üzerinde durur, koyu temada da aynı görünmelidir.
  static const _light = Color(0xFFFFD88A);

  @override
  void paint(Canvas canvas, Size size) {
    final cable = Path()
      ..moveTo(anchors.left.dx, anchors.left.dy)
      ..quadraticBezierTo(
        anchors.sag.dx,
        anchors.sag.dy + (anchors.sag.dy - anchors.left.dy),
        anchors.right.dx,
        anchors.right.dy,
      );
    canvas.drawPath(
      cable,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: .35 * opacity),
    );

    // Yazı iki minare arasına sığmalı. Uzun Türkçe cümleler ve Arapça metin
    // dar ekranda taşardı; tuvali küçültmek yerine YAZI BOYUTU küçültülür.
    // Tuval ölçeği parıltıyı da büyütüyor ve harfler birbirine yapışıp tek
    // bir ışık çubuğuna dönüşüyordu.
    final available = anchors.width - 24;
    var fontSize = _baseFontSize;
    var painter = _layout(fontSize);
    if (painter.width > available) {
      // Ölçü ELDEN ÇIKARMADAN önce alınır: atılmış bir TextPainter'ın
      // genişliğini okumak hata fırlatır ve yazı hiç çizilmez.
      final fitted = math.max(
        _minimumFontSize,
        fontSize * available / painter.width,
      );
      painter.dispose();
      fontSize = fitted;
      painter = _layout(fontSize);
    }

    canvas.save();
    // Kabloyla yazı arasındaki askı telleri.
    final hangerPaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: .3 * opacity);
    final top = anchors.sag.dy;
    final textTop = top + fontSize * .6;
    for (var i = 1; i <= 4; i++) {
      final x = anchors.left.dx + anchors.width * i / 5;
      canvas.drawLine(Offset(x, top + 2), Offset(x, textTop), hangerPaint);
    }
    canvas.restore();

    painter.paint(canvas, Offset(anchors.sag.dx - painter.width / 2, textTop));
    painter.dispose();
  }

  /// Yazının tam boyu. Dar ekranda buradan küçültülür.
  static const _baseFontSize = 20.0;

  /// Bunun altında yazı okunmaz; mahya o ekranda dar kalır ama okunur.
  static const _minimumFontSize = 9.0;

  TextPainter _layout(double fontSize) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: _light.withValues(alpha: opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        // Ampul dizisi hissi: harfler birbirine değmez.
        letterSpacing: fontSize * .06,
        height: 1,
        shadows: [
          // Parıltı yazı boyutuna bağlıdır. Sabit bırakıldığında küçülen
          // yazıda harfler birbirine yapışıp ışık çubuğuna dönüşüyor.
          BoxShadow(
            color: _light.withValues(alpha: .7 * opacity),
            blurRadius: fontSize * .45,
          ),
          BoxShadow(
            color: const Color(0xFFFF9D3C).withValues(alpha: .45 * opacity),
            blurRadius: fontSize * .9,
          ),
        ],
      ),
    ),
    textDirection: textDirection,
    maxLines: 1,
  )..layout();

  @override
  bool shouldRepaint(MahyaPainter old) =>
      old.text != text ||
      old.opacity != opacity ||
      old.anchors.left != anchors.left ||
      old.anchors.right != anchors.right ||
      old.textDirection != textDirection;
}
