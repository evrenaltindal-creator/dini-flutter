import '../../../shared/models/domain.dart';
import 'prayer_tracker.dart';

/// Kaza (kılınmamış farz) namazların sayacı.
///
/// **Uygulama kimseye kaç kaza borcu olduğunu söylemez.** Sayıyı kullanıcı
/// kendisi girer ve kıldıkça düşer; ekran, borcun nasıl hesaplanacağının bir
/// fetva konusu olduğunu söyleyip Diyanet'e yönlendirir.
class QadaLog {
  /// Vakit başına kalan kaza sayısı. Sıfır olanlar haritada durmaz.
  final Map<Prayer, int> counts;

  const QadaLog({this.counts = const {}});

  int countOf(Prayer prayer) => counts[prayer] ?? 0;

  int get total =>
      trackedPrayers.fold(0, (sum, prayer) => sum + countOf(prayer));

  /// Kaza kalmadı mı?
  bool get isEmpty => total == 0;

  /// Bir vaktin sayısını değiştirir; sıfırın altına inmez.
  ///
  /// Negatif bir kaza sayısı anlamsızdır ve toplamı sessizce bozardı.
  QadaLog withPrayer(Prayer prayer, int value) {
    final next = {...counts};
    if (value <= 0) {
      next.remove(prayer);
    } else {
      next[prayer] = value;
    }
    return QadaLog(counts: next);
  }

  /// Her vakte [days] gün ekler.
  ///
  /// Biriken kaza genelde gün ya da yıl olarak hatırlanır; tek tek beş vakti
  /// elle girmek yerine gün olarak eklenebilmeli.
  QadaLog addDays(int days) {
    if (days <= 0) return this;
    var result = this;
    for (final prayer in trackedPrayers) {
      result = result.withPrayer(prayer, result.countOf(prayer) + days);
    }
    return result;
  }
}

/// Kaza eklerken sunulan hazır gün seçenekleri.
///
/// Bir gün, bir hafta, bir ay ve bir yıl. Yıl 365 gündür; hicri yılı esas
/// almak sayıyı daha doğru yapmaz, çünkü zaten kullanıcının tahminidir.
const qadaDayChoices = [1, 7, 30, 365];
