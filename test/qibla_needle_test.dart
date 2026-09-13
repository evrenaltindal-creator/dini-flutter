import 'package:dini_flutter/features/qibla/domain/qibla_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shortestDelta', () {
    test('takes the short way across the +/-180 boundary', () {
      // Kullanıcı kıblenin tam arkasındaki noktadan geçerken fark +179'dan
      // -179'a atlar. Aradaki gerçek dönüş 2 derecedir, -358 değil.
      expect(QiblaNeedle.shortestDelta(from: 179, to: -179), closeTo(2, .001));
      expect(QiblaNeedle.shortestDelta(from: -179, to: 179), closeTo(-2, .001));
    });

    test('keeps ordinary movements unchanged', () {
      expect(QiblaNeedle.shortestDelta(from: 0, to: 30), closeTo(30, .001));
      expect(QiblaNeedle.shortestDelta(from: 30, to: 0), closeTo(-30, .001));
      expect(QiblaNeedle.shortestDelta(from: -10, to: 10), closeTo(20, .001));
    });

    test('never returns a turn longer than half a circle', () {
      for (var from = -180; from <= 180; from += 7) {
        for (var to = -180; to <= 180; to += 11) {
          final delta = QiblaNeedle.shortestDelta(
            from: from.toDouble(),
            to: to.toDouble(),
          );
          expect(
            delta.abs(),
            lessThanOrEqualTo(180.001),
            reason: '$from -> $to için delta $delta, uzun yoldan dönüyor.',
          );
        }
      }
    });
  });

  group('QiblaNeedle', () {
    test('starts from the first reading without spinning', () {
      final needle = const QiblaNeedle().update(90);
      expect(needle.turns, closeTo(.25, .0001));
      expect(needle.lastDifference, 90);
    });

    test('crossing behind the qibla moves the needle only slightly', () {
      var needle = const QiblaNeedle().update(179);
      final before = needle.turns;
      needle = needle.update(-179);

      // Ham değer kullanılsaydı fark .497'den -.497'ye, yani neredeyse tam
      // tur atardı. En kısa yol yalnızca 2 derece, yani 2/360 turdur.
      expect(needle.turns - before, closeTo(2 / 360, .0001));
    });

    test('a full slow rotation never jumps more than a few degrees', () {
      var needle = const QiblaNeedle();
      var previous = 0.0;
      var maxJump = 0.0;

      // Telefonu 5 derecelik adımlarla tam tur çevir: fark ±180 sınırından
      // mutlaka geçer. Hiçbir adımda ok 5 dereceden fazla sıçramamalı.
      for (var heading = 0; heading <= 360; heading += 5) {
        final difference = const QiblaCalculator().turnDifference(
          bearing: 30,
          heading: heading.toDouble(),
        );
        needle = needle.update(difference);
        if (heading > 0) {
          final jump = (needle.turns - previous).abs();
          if (jump > maxJump) maxJump = jump;
        }
        previous = needle.turns;
      }

      expect(
        maxJump,
        lessThanOrEqualTo(6 / 360),
        reason:
            'Ok bir adımda ${(maxJump * 360).toStringAsFixed(1)} derece '
            'sıçradı; sınırdan geçerken ters yöne tam tur atıyor.',
      );
    });

    test('the accumulated turn tracks the real rotation of the phone', () {
      var needle = const QiblaNeedle();
      for (var heading = 0; heading <= 360; heading += 5) {
        needle = needle.update(
          const QiblaCalculator().turnDifference(
            bearing: 30,
            heading: heading.toDouble(),
          ),
        );
      }
      // Telefon tam tur döndü, kıble sabit: ok da tam tur (ters yönde) dönmeli.
      expect(needle.turns, closeTo(30 / 360 - 1, .01));
    });
  });
}
