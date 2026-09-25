import 'package:dini_flutter/features/home/domain/scene_layout.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/ramadan/domain/mahya_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı (iPad'de): "uygulama ilk açıldığında cami gözükmüyor, sadece
/// güneş veya ay gözüküyor."
///
/// Sahne görseli telefon oranındadır. Ekranı doldurup üstten hizalamak
/// geniş ekranda görseli o kadar büyütüyordu ki ekrana yalnızca gökyüzü
/// sığıyordu.
void main() {
  const image = mosqueSceneImageSize;
  const screens = {
    'iPhone': Size(390, 844),
    'iPhone Pro Max': Size(440, 956),
    'iPhone yatay': Size(844, 390),
    'iPad mini': Size(744, 1133),
    'iPad Air': Size(820, 1180),
    'iPad Pro 13': Size(1032, 1376),
    'iPad Air yatay': Size(1180, 820),
    'iPad Pro 13 yatay': Size(1376, 1032),
    'iPad bölünmüş ekran': Size(678, 1024),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    test('$name: caminin tamamı görünür, ekranda boşluk kalmaz', () {
      final rect = mosqueSceneRect(screen: screen, image: image);
      final mosqueTopY = rect.top + mosqueTop * rect.height;
      final mosqueBottomY = rect.top + mosqueBottom * rect.height;
      expect(mosqueTopY, greaterThanOrEqualTo(-0.5), reason: 'minare uçları');
      expect(
        mosqueBottomY,
        lessThanOrEqualTo(screen.height + 0.5),
        reason: 'revaklar',
      );
      // Dikeyde ekran her zaman dolu; yanları gerekirse bulanık dolgu
      // kapatır.
      expect(rect.top, lessThanOrEqualTo(0.5));
      expect(rect.bottom, greaterThanOrEqualTo(screen.height - 0.5));
      if (!mosqueSceneNeedsSideFill(screen: screen, image: image)) {
        expect(rect.left, lessThanOrEqualTo(0.5));
        expect(rect.right, greaterThanOrEqualTo(screen.width - 0.5));
      }
    });
  }

  test('telefonda görünüm değişmedi: ekranı doldurur, üstten hizalı', () {
    final rect = mosqueSceneRect(screen: const Size(390, 844), image: image);
    expect(rect.top, 0);
    expect(rect.width, closeTo(390, .01));
    expect(
      mosqueSceneNeedsSideFill(screen: const Size(390, 844), image: image),
      isFalse,
    );
  });

  test('iPad dikeyde görsel ekranı doldurur, cami için yukarı kayar', () {
    const screen = Size(1032, 1376);
    final rect = mosqueSceneRect(screen: screen, image: image);
    expect(mosqueSceneNeedsSideFill(screen: screen, image: image), isFalse);
    expect(rect.top, lessThan(0));
  });

  test('yatayda yanlar bulanık dolguyla kapanır', () {
    for (final screen in [const Size(1376, 1032), const Size(844, 390)]) {
      expect(
        mosqueSceneNeedsSideFill(screen: screen, image: image),
        isTrue,
        reason: '$screen',
      );
    }
  });

  test('mahya iPad yatayda da minarelerin üstündedir', () {
    const screen = Size(1376, 1032);
    final rect = mosqueSceneRect(screen: screen, image: image);
    final anchors = mahyaAnchors(screen: screen, image: image)!;
    expect(
      anchors.left.dx,
      closeTo(rect.left + mahyaLeftAnchor.dx * rect.width, 1),
    );
    expect(
      anchors.right.dx,
      closeTo(rect.left + mahyaRightAnchor.dx * rect.width, 1),
    );
    expect(
      anchors.left.dy,
      closeTo(rect.top + mahyaLeftAnchor.dy * rect.height, 1),
    );
  });

  testWidgets('sahne yatay iPad\'de bulanık yan dolguyu çizer', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 1376,
            height: 1032,
            child: SceneImage(asset: 'assets/scenes/mosque_night.png'),
          ),
        ),
      ),
    );
    expect(find.byKey(SceneImage.sideFillKey), findsOneWidget);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 390,
            height: 844,
            child: SceneImage(asset: 'assets/scenes/mosque_night.png'),
          ),
        ),
      ),
    );
    expect(find.byKey(SceneImage.sideFillKey), findsNothing);
  });
}
