import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'quran_style.dart';

/// Sayfaları gerçek bir kitap gibi çevirir.
///
/// Cilt soldadır (kullanıcı kararı: normal kitap gibi, kapakla aynı yön).
/// Parmakla sola çekilen sayfa sol kenarının üzerinde dönerek kalkar;
/// yarıda bırakılırsa geri düşer, yeterince çekilirse ya da hızlı
/// fırlatılırsa tamamlanır. Sağa çekince önceki sayfa geri gelir. Sayfanın
/// sağ ve sol kenarına dokunmak da çevirir. Dönen sayfanın arka yüzü düz
/// kâğıttır; alttaki sayfaya gölgesi düşer.
class PageTurner extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  const PageTurner({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialPage = 0,
    this.onPageChanged,
  });

  /// Bu kadar çekilirse (genişliğin oranı) sayfa bırakınca tamamlanır.
  static const commitFraction = .35;

  /// Bu hızdan (px/sn) hızlı fırlatılırsa mesafeye bakılmaz.
  static const flingVelocity = 450.0;

  static const turningKey = ValueKey('page-turner-turning');

  @override
  State<PageTurner> createState() => PageTurnerState();
}

enum _Direction { forward, backward }

class PageTurnerState extends State<PageTurner>
    with SingleTickerProviderStateMixin {
  late int page = widget.initialPage.clamp(0, widget.itemCount - 1);

  /// Dönen sayfanın ilerlemesi: 0 başlangıç, 1 tamamlandı.
  late final AnimationController progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  _Direction? _direction;
  double dragged = 0;

  int get currentPage => page;

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  bool _canGo(_Direction to) =>
      to == _Direction.forward ? page < widget.itemCount - 1 : page > 0;

  /// Çevirmeyi başlatır. Sürüklemede şimdiye kadarki mesafe korunur:
  /// sıfırlansaydı parmağın ilk hareketi kaybolur, sayfa yeterince
  /// çekilmemiş sayılırdı.
  void _start(_Direction to) {
    if (!_canGo(to)) return;
    setState(() => _direction = to);
    progress.value = 0;
  }

  void _onDragStart(DragStartDetails details) {
    if (!progress.isAnimating && _direction == null) dragged = 0;
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (progress.isAnimating) return;
    dragged += details.delta.dx;
    if (_direction == null) {
      if (dragged.abs() < 4) return;
      _start(dragged < 0 ? _Direction.forward : _Direction.backward);
      if (_direction == null) return;
    }
    final sign = _direction == _Direction.forward ? -1 : 1;
    progress.value = (sign * dragged / width).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_direction == null) return;
    final velocity = details.primaryVelocity ?? 0;
    final towards = _direction == _Direction.forward ? -velocity : velocity;
    final commit =
        towards > PageTurner.flingVelocity ||
        (towards > -PageTurner.flingVelocity &&
            progress.value > PageTurner.commitFraction);
    _settle(commit);
  }

  Future<void> _settle(bool commit) async {
    if (commit) {
      await progress.animateTo(1, curve: Curves.easeOut);
      if (!mounted) return;
      setState(() {
        page += _direction == _Direction.forward ? 1 : -1;
        _direction = null;
      });
      progress.value = 0;
      widget.onPageChanged?.call(page);
    } else {
      await progress.animateBack(0, curve: Curves.easeOut);
      if (!mounted) return;
      setState(() => _direction = null);
    }
  }

  /// Bir sonraki sayfaya çevirir (kenara dokununca da çağrılır).
  Future<void> next() async {
    if (_direction != null || !_canGo(_Direction.forward)) return;
    _start(_Direction.forward);
    await _settle(true);
  }

  /// Bir önceki sayfaya döner.
  Future<void> previous() async {
    if (_direction != null || !_canGo(_Direction.backward)) return;
    _start(_Direction.backward);
    await _settle(true);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
        onHorizontalDragEnd: _onDragEnd,
        onTapUp: (details) {
          // Kenarlara dokunmak çevirir; ortaya dokunmak metni okumaya
          // bırakılır.
          final x = details.localPosition.dx;
          if (x > width * .8) next();
          if (x < width * .2) previous();
        },
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) => _pages(context),
        ),
      );
    },
  );

  Widget _pages(BuildContext context) {
    final turning = _direction;
    if (turning == null) return widget.itemBuilder(context, page);

    // İleri: altta sonraki sayfa, üstte şimdiki sayfa kalkar.
    // Geri: altta şimdiki sayfa, üstte önceki sayfa geri iner.
    final forward = turning == _Direction.forward;
    final under = forward ? page + 1 : page;
    final over = forward ? page : page - 1;
    final t = progress.value;
    final angle = (forward ? t : 1 - t) * math.pi;
    final lift = math.sin(angle);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.itemBuilder(context, under),
        // Kalkan sayfanın alttakine düşen gölgesi.
        IgnorePointer(
          child: ColoredBox(color: Colors.black.withValues(alpha: .28 * lift)),
        ),
        Transform(
          key: PageTurner.turningKey,
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0006)
            ..rotateY(angle),
          child: angle <= math.pi / 2
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.itemBuilder(context, over),
                    // Kalktıkça cilde yakın taraf kararır.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: .25 * lift),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const _PageBack(),
        ),
      ],
    );
  }
}

/// Dönen sayfanın arka yüzü: düz kâğıt, cilde doğru gölge.
class _PageBack extends StatelessWidget {
  const _PageBack();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      gradient: LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [QuranPalette.paperEdge, QuranPalette.paper],
      ),
    ),
  );
}
