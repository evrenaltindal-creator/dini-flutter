import 'islamic_calendar.dart';

/// Bir günün Ramazan'a göre konumu.
enum RamadanPhase {
  /// Ramazan yaklaşıyor ama henüz başlamadı.
  approaching,

  /// Ramazan içindeyiz.
  during,

  /// Ramazan'ın son on günü — Kadir Gecesi bu aralıktadır.
  lastTen,

  /// Ramazan bitti, bayram yaklaşıyor ya da bugün.
  eid,

  /// Ramazan'a daha çok var; geri sayım gösterilmez.
  far,
}

/// Ramazan geri sayımının tek kaynağı.
///
/// Hicri takvim burada dışarıdan verilir: kullanıcının tarih düzeltmesi
/// uygulanmazsa geri sayım, bildirimlerin planlandığı günden farklı bir gün
/// gösterir.
class RamadanStatus {
  final RamadanPhase phase;

  /// Ramazan'ın kaçıncı günü. Yalnızca [RamadanPhase.during] ve
  /// [RamadanPhase.lastTen] için doludur.
  final int? dayOfRamadan;

  /// Ramazan'ın başlamasına ya da bayrama kalan gün. Bugünse sıfır.
  final int? daysRemaining;

  const RamadanStatus({
    required this.phase,
    this.dayOfRamadan,
    this.daysRemaining,
  });

  /// Ana ekranda bir Ramazan kartı gösterilmeli mi?
  bool get isVisible => phase != RamadanPhase.far;

  /// Oruç tutulan bir gün mü?
  bool get isFasting =>
      phase == RamadanPhase.during || phase == RamadanPhase.lastTen;
}

/// Ramazan'ın hicri ay numarası ve onu izleyen Şevval.
const _ramadan = 9;
const _shawwal = 10;

/// Geri sayımın kaç gün önceden görünmeye başladığı.
///
/// Kırk gün, "yaklaşıyor" demek için makul bir pencere: Şaban'ın başından
/// itibaren görünür, yılın geri kalanında ana ekranı meşgul etmez.
const ramadanCountdownWindow = 40;

/// Bayram kartının kaç gün gösterileceği. Şevval'in ilk üç günü bayramdır.
const _eidWindow = 3;

/// [date] gününün Ramazan'a göre durumunu çıkarır.
RamadanStatus ramadanStatus(
  DateTime date, {
  IslamicCalendar calendar = const IslamicCalendar(),
}) {
  final today = DateTime(date.year, date.month, date.day);
  final hijri = calendar.hijri(today);

  if (hijri.month == _ramadan) {
    // Ramazan 29 ya da 30 gün sürer; son on gün 21. günde başlar.
    return RamadanStatus(
      phase: hijri.day >= 21 ? RamadanPhase.lastTen : RamadanPhase.during,
      dayOfRamadan: hijri.day,
      daysRemaining: 0,
    );
  }

  if (hijri.month == _shawwal && hijri.day <= _eidWindow) {
    return RamadanStatus(phase: RamadanPhase.eid, daysRemaining: 0);
  }

  // Ramazan'ın ilk gününü ileriye doğru arar. Hicri ay uzunluğu tabloya
  // bağlı olduğu için gün sayısı hesaplanmaz, gerçekten sayılır.
  for (var ahead = 1; ahead <= ramadanCountdownWindow; ahead++) {
    final candidate = today.add(Duration(days: ahead));
    if (calendar.hijri(candidate).month == _ramadan &&
        calendar.hijri(candidate).day == 1) {
      return RamadanStatus(
        phase: RamadanPhase.approaching,
        daysRemaining: ahead,
      );
    }
  }

  return const RamadanStatus(phase: RamadanPhase.far);
}
