import 'fasting_log.dart';

/// Bir gecede kılınan teravih rekâtları.
///
/// **Hedef rekât sayısı bir hüküm değildir.** Uygulamada yirmi rekât
/// varsayılan gelir; Türkiye'de camilerde kılınan sayı budur. Farklı
/// uygulamalar için hedef değiştirilebilir ve ekran, sayının bir fetva
/// konusu olduğunu söyleyip Diyanet'e yönlendirir.
const teravihTargetChoices = [8, 20];

/// Varsayılan hedef.
const teravihDefaultTarget = 20;

/// Bir dokunuşun eklediği rekât: teravih iki rekâtta bir selam verilerek
/// kılınır, sayaç da selam selam ilerler.
const teravihStep = 2;

/// Bir Ramazan'ın teravih kaydı.
class TeravihLog {
  final RamadanSpan span;

  /// Gece numarası → kılınan rekât.
  final Map<int, int> rekats;

  /// Gecelik hedef.
  final int target;

  const TeravihLog({
    required this.span,
    this.rekats = const {},
    this.target = teravihDefaultTarget,
  });

  int rekatsOf(int night) => rekats[night] ?? 0;

  /// En az bir rekât kılınan gece sayısı.
  int get nightsPrayed => rekats.values.where((value) => value > 0).length;

  /// Hedefe ulaşılan gece sayısı.
  int get nightsCompleted =>
      rekats.values.where((value) => value >= target).length;

  int get totalRekats => rekats.values.fold(0, (total, value) => total + value);

  /// [night] gecesinin sayısını değiştirir.
  ///
  /// Sayı sıfırın altına inmez ve hedefin üstüne çıkabilir: cemaatle kılınan
  /// rekât sayısı camiye göre değişir, sayacı hedefte kilitlemek kullanıcıyı
  /// yanlış bir sayıya zorlardı.
  TeravihLog withNight(int night, int value) {
    final next = {...rekats};
    if (value <= 0) {
      next.remove(night);
    } else {
      next[night] = value;
    }
    return TeravihLog(span: span, rekats: next, target: target);
  }

  TeravihLog withTarget(int value) =>
      TeravihLog(span: span, rekats: rekats, target: value);
}
