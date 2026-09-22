import Foundation

/// Tek bir vakit.
struct PrayerMoment: Identifiable, Equatable {
  let key: String
  let label: String
  let time: Date

  var id: String { "\(key)-\(Int(time.timeIntervalSince1970))" }
}

/// Telefondan gelen çizelge.
///
/// Biçim Dart tarafındaki `WatchSchedule.toPayload` ile aynıdır: anlar Unix
/// saniyesi (tarih metni değil), değeri olmayan anahtar hiç yazılmaz (null
/// yok). İkisi de telefon widget'ında pahalıya öğrenildi.
struct WatchSchedule: Equatable {
  static let prayerKeys = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]

  let generatedAt: Date
  let locationName: String?
  let timeZone: TimeZone
  let texts: [String: String]
  /// Günler, telefonun seçilen şehre göre saydığı sırayla.
  let days: [[PrayerMoment]]

  init?(payload: [String: Any]) {
    guard
      let generated = (payload["generatedAt"] as? NSNumber)?.doubleValue,
      let rawDays = payload["days"] as? [[String: Any]]
    else { return nil }

    let labels = payload["labels"] as? [String: String] ?? [:]
    var days: [[PrayerMoment]] = []
    for rawDay in rawDays {
      var moments: [PrayerMoment] = []
      for key in Self.prayerKeys {
        guard let seconds = (rawDay[key] as? NSNumber)?.doubleValue else { continue }
        moments.append(
          PrayerMoment(
            key: key,
            label: labels[key] ?? key.capitalized,
            time: Date(timeIntervalSince1970: seconds)
          )
        )
      }
      if !moments.isEmpty { days.append(moments.sorted { $0.time < $1.time }) }
    }
    guard !days.isEmpty else { return nil }

    self.generatedAt = Date(timeIntervalSince1970: generated)
    self.locationName = payload["locationName"] as? String
    // Şehrin dilimi bilinmiyorsa saatin kendi dilimi kullanılır; yanlış
    // bir dilimle yazmaktan iyidir.
    self.timeZone =
      (payload["timezoneId"] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
    self.texts = payload["texts"] as? [String: String] ?? [:]
    self.days = days
  }

  /// [now]'dan sonraki ilk vakit; çizelge bittiyse nil.
  func next(after now: Date) -> PrayerMoment? {
    for day in days {
      if let moment = day.first(where: { $0.time > now }) { return moment }
    }
    return nil
  }

  /// [moment]'in bulunduğu günün bütün vakitleri.
  func day(of moment: PrayerMoment) -> [PrayerMoment] {
    days.first { $0.contains(moment) } ?? []
  }

  /// Telefondan gelen arayüz metni; gelmemişse saatin kendi yedeği.
  func text(_ key: String) -> String {
    texts[key] ?? WatchFallbackText.text(key)
  }

  /// Vakti şehrin duvar saatinde yazar.
  ///
  /// `Text(date, style: .time)` saatin kendi dilimini kullanır; yolculukta
  /// telefon ile saat farklı saat gösterirdi.
  func clock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

/// Telefonla hiç eşleşmemiş saatin metinleri.
///
/// Bütün diğer metinler telefondan hazır gelir (uygulamanın üç dilli çeviri
/// haritasından). Çizelge daha hiç gelmediyse saatin elinde telefon metni
/// yoktur; bu küçük tablo yalnızca o durum içindir.
enum WatchFallbackText {
  private static let table: [String: [String: String]] = [
    "tr": [
      "watch.next": "Sıradaki",
      "watch.today": "Bugün",
      "watch.stale": "Vakitler güncel değil. Telefonda Namaz Yolu'nu açın.",
      "watch.empty": "Vakitler için telefonda Namaz Yolu'nu bir kez açın.",
    ],
    "en": [
      "watch.next": "Next",
      "watch.today": "Today",
      "watch.stale": "Times are out of date. Open Prayer Path on your phone.",
      "watch.empty": "Open Prayer Path on your phone once to get prayer times.",
    ],
    "ar": [
      "watch.next": "التالية",
      "watch.today": "اليوم",
      "watch.stale": "المواقيت غير محدّثة. افتح طريق الصلاة على هاتفك.",
      "watch.empty": "افتح طريق الصلاة على هاتفك مرة واحدة للحصول على المواقيت.",
    ],
  ]

  static func text(_ key: String) -> String {
    let language = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "tr"
    return table[language]?[key] ?? table["tr"]?[key] ?? key
  }
}
