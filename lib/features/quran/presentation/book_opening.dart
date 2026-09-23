import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import 'quran_style.dart';

/// Kuran sekmesine her girişte bir artar; kapak yeniden açılır.
///
/// Sekme durumu korunduğu için sayfa ikinci girişte yeniden kurulmaz;
/// açılışı sekme çubuğu bu sayaçla tetikler.
final quranOpenedProvider = StateProvider<int>((ref) => 0);

/// Kuran sekmesine girerken kapalı bir Mushaf görünür ve kapağı açılır.
///
/// Mushaf sağdan açılır: kapağın menteşesi (sırtı) sağdadır ve kapak
/// izleyene doğru dönerek sağa açılır. Dönerken kapağın iç yüzü (forza
/// kâğıdı) görünür, arkadan ilk sayfa ve sonra içerik belirir. Dokununca
/// hemen biter; "hareketi azalt" açıksa hiç oynatılmaz.
class BookOpening extends ConsumerStatefulWidget {
  final Widget child;

  const BookOpening({super.key, required this.child});

  static const coverKey = ValueKey('quran-book-cover');
  static const duration = Duration(milliseconds: 1500);

  @override
  ConsumerState<BookOpening> createState() => _BookOpeningState();
}

class _BookOpeningState extends ConsumerState<BookOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: BookOpening.duration,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(quranOpenedProvider, (_, _) => _open());
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final t = controller.value;
        if (t >= 1) return child!;
        // Kapak ilk %65'te açılır; kitap sonra kaybolur ve içerik ancak
        // ondan sonra belirir: ikisi üst üste binince yazılar karışıyordu.
        final open = Curves.easeInOutCubic.transform((t / .65).clamp(0, 1));
        final bookFade = Curves.easeIn.transform(((t - .62) / .2).clamp(0, 1));
        final reveal = Curves.easeOut.transform(((t - .75) / .25).clamp(0, 1));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.value = 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: reveal,
                child: Transform.scale(
                  scale: lerpDouble(.94, 1, reveal),
                  child: child,
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: 1 - bookFade,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      28,
                      40,
                      28,
                      110,
                    ),
                    child: _Book(open: open),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Kapak ve altındaki ilk sayfa. [open] 0 kapalı, 1 tamamen açık.
class _Book extends StatelessWidget {
  final double open;

  const _Book({required this.open});

  @override
  Widget build(BuildContext context) {
    // 0 → 0°, 1 → 160°: kapak sırtın üzerinde sağa doğru döner.
    final angle = open * math.pi * .89;
    final showingInside = angle > math.pi / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Kapağın altındaki ilk sayfa.
        const _FirstPage(),
        Transform(
          alignment: Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateY(-angle),
          child: Container(
            key: BookOpening.coverKey,
            child: showingInside
                // Arka yüz ayna gibi görünmesin diye çevrilir.
                ? Transform.flip(flipX: true, child: const _Endpaper())
                : const _Cover(),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: const BorderRadiusDirectional.horizontal(
        start: Radius.circular(10),
        end: Radius.circular(4),
      ).resolve(TextDirection.ltr),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF155C4A), QuranPalette.green, QuranPalette.greenDeep],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: CustomPaint(
      painter: const _CoverPainter(),
      child: Center(
        child: SizedBox.square(
          dimension: 190,
          child: CustomPaint(
            painter: const RubElHizbPainter(
              stroke: QuranPalette.goldLight,
              fill: Color(0x33000000),
              strokeWidth: 2,
              ring: true,
            ),
            child: Center(
              child: Text(
                'القرآن\nالكريم',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: quranTitleFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  height: 1.25,
                  color: QuranPalette.goldLight,
                  shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Kapak süsü: altın çift çerçeve, köşe yıldızları ve sağda sırt gölgesi.
class _CoverPainter extends CustomPainter {
  const _CoverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Sırt: sağ kenarda koyu şerit ve sırt çizgileri.
    final spine = Rect.fromLTWH(size.width - 22, 0, 22, size.height);
    canvas.drawRect(
      spine,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), Color(0x66000000)],
        ).createShader(spine),
    );
    final gold = Paint()
      ..color = QuranPalette.gold
      ..style = PaintingStyle.stroke;
    for (final y in [size.height * .12, size.height * .88]) {
      canvas.drawLine(
        Offset(size.width - 20, y),
        Offset(size.width - 2, y),
        gold..strokeWidth = 1.4,
      );
    }

    final outer = Rect.fromLTWH(16, 16, size.width - 52, size.height - 32);
    canvas.drawRect(outer, gold..strokeWidth = 2.4);
    canvas.drawRect(
      outer.deflate(8),
      gold
        ..strokeWidth = 1
        ..color = QuranPalette.goldLight,
    );
    for (final corner in [
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      canvas.save();
      canvas.translate(corner.dx - 16, corner.dy - 16);
      const RubElHizbPainter(
        stroke: QuranPalette.goldLight,
        fill: QuranPalette.greenDeep,
        strokeWidth: 1.4,
      ).paint(canvas, const Size(32, 32));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => false;
}

/// Kapağın iç yüzü: altın yıldız desenli forza kâğıdı.
class _Endpaper extends StatelessWidget {
  const _Endpaper();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: QuranPalette.greenDeep,
      borderRadius: BorderRadius.circular(6),
    ),
    child: CustomPaint(painter: const _EndpaperPainter()),
  );
}

class _EndpaperPainter extends CustomPainter {
  const _EndpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 34.0;
    for (var y = cell / 2; y < size.height; y += cell) {
      for (var x = cell / 2; x < size.width; x += cell) {
        canvas.save();
        canvas.translate(x - 7, y - 7);
        const RubElHizbPainter(
          stroke: Color(0x88E2C275),
          strokeWidth: .8,
        ).paint(canvas, const Size(14, 14));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_EndpaperPainter old) => false;
}

/// Kapak kalkınca görünen ilk sayfa: tezhipli çerçeve ve Besmele.
class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) => MushafFrame(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BasmalaLine(text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
          const SizedBox(height: 8),
          Text(
            context.l10n.text('nav.quran'),
            style: const TextStyle(
              color: QuranPalette.mutedInk,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}
