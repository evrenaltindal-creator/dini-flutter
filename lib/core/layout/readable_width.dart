import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Geniş ekranda (iPad, yatay) içeriğin en fazla ne kadar genişleyeceği.
///
/// Uygulama telefon için tasarlandı; kartlar ve listeler 1376 noktalık bir
/// iPad ekranına yayılınca satırlar okunmaz uzunlukta oluyor, kartlar
/// boş kalıyordu. İçerik bu genişlikte ortalanır; arka plan (cami sahnesi)
/// ekranın tamamını kaplamaya devam eder. Telefonda hiçbir şey değişmez.
const readableContentWidth = 720.0;

/// İçeriği [readableContentWidth] genişliğinde ortalar.
class ReadableWidth extends StatelessWidget {
  final Widget child;

  const ReadableWidth({required this.child, super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: readableContentWidth),
      child: child,
    ),
  );
}

/// Tam genişlikte kalması gereken bir kaydırıcı (arkasındaki degrade tam
/// ekran olsun, kenarlardan da kaydırılabilsin) için yan boşluk: içerik
/// [readableContentWidth] genişliğinde ortada durur, dar ekranda [minimum]
/// kalır.
double readableSideInset(BuildContext context, {double minimum = 16}) {
  final width = MediaQuery.sizeOf(context).width;
  return math.max(minimum, (width - readableContentWidth) / 2 + minimum);
}
