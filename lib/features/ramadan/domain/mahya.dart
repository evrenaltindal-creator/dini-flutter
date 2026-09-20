import '../../calendar/domain/islamic_calendar.dart';
import '../../calendar/domain/ramadan_status.dart';
import '../../home/domain/mosque_scene_state.dart';
import 'ramadan_night.dart';

/// Minareler arasına asılan ışıklı yazı.
///
/// Mahya yalnızca Ramazan gecelerinde yanar ve yazısı değişir. Buradaki
/// metinler geleneksel mahya yazılarıdır — tebrik ve karşılama sözleridir,
/// dinî bir hüküm ya da hadis aktarımı değildir. Uygulama dinî içerikte
/// kaynak göstermeden hüküm aktarmaz; mahya metinleri kültürel bir gelenek
/// olduğu için bu kuralın dışında kalır ve "Hakkında" ekranında böyle
/// anlatılır.
class Mahya {
  /// Yazının metin anahtarı; üç dilde de karşılığı vardır.
  final String textKey;

  /// Gecenin Ramazan'ın kaçıncı gecesi olduğu. Bayram gecesinde boştur.
  final int? nightOfRamadan;

  const Mahya(this.textKey, {this.nightOfRamadan});
}

/// Genel mahya yazılarının sayısı. Yazı **haftada bir** değişir: her gece
/// değiştirmek yılın geri kalanında hatırlanmayan bir ayrıntı olurdu,
/// haftalık değişim ise ayın ilerlediğini hissettirir.
const mahyaGeneralPhrases = 4;

/// Kadir Gecesi'nin geleneksel olarak arandığı gece.
///
/// Kesin gece bildirilmemiştir; Diyanet de yirmi yedinci geceyi "idrak
/// edilen" gece olarak anar. Mahya bu yüzden bir hüküm değil, o geceye
/// özel bir tebriktir.
const mahyaQadrNight = 27;

/// Mahyanın yandığı zaman dilimleri: akşamdan imsağa kadar.
bool mahyaIsLit(MosqueScenePeriod period) => switch (period) {
  MosqueScenePeriod.maghrib ||
  MosqueScenePeriod.ishaNight ||
  MosqueScenePeriod.preFajrNight => true,
  _ => false,
};

/// Akşam ezanı okundu mu? Hicri gün akşam başlar: akşamdan sonraki mahya
/// ertesi günün gecesine aittir.
bool mahyaAfterMaghrib(MosqueScenePeriod period) =>
    period == MosqueScenePeriod.maghrib ||
    period == MosqueScenePeriod.ishaNight;

/// [date] gününde yanan mahya; Ramazan gecesi değilse null.
///
/// [afterMaghrib] doğruysa gece ertesi güne aittir. Ramazan'dan önceki son
/// akşam bu yüzden "hoş geldin" mahyasını yakar: o akşam Ramazan'ın ilk
/// gecesidir, henüz ilk orucu tutulmamış olsa da.
Mahya? mahyaFor(
  DateTime date, {
  required bool afterMaghrib,
  IslamicCalendar calendar = const IslamicCalendar(),
}) {
  final night = ramadanNightDate(date, afterMaghrib: afterMaghrib);
  final status = ramadanStatus(night, calendar: calendar);

  if (status.phase == RamadanPhase.eid) return const Mahya('mahya.eid');
  if (!status.isFasting) return null;

  final day = status.dayOfRamadan!;
  if (day == 1) return Mahya('mahya.welcome', nightOfRamadan: day);
  if (day == mahyaQadrNight) return Mahya('mahya.qadr', nightOfRamadan: day);

  // Ramazan 29 ya da 30 gün sürer; son gece hesapla bulunmaz, ertesi günün
  // hicri ayına bakılarak bulunur.
  final tomorrow = calendar.hijri(night.add(const Duration(days: 1)));
  if (tomorrow.month != 9) {
    return Mahya('mahya.farewell', nightOfRamadan: day);
  }

  final week = (day - 1) ~/ 7 % mahyaGeneralPhrases + 1;
  return Mahya('mahya.week$week', nightOfRamadan: day);
}
