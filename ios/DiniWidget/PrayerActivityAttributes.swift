import ActivityKit
import Foundation

/// Canlı etkinliğin verisi.
///
/// Bu dosya **iki hedefte birden** derlenir: etkinliği başlatan uygulama
/// (`LiveActivityBridge.swift`) ve onu çizen widget uzantısı
/// (`PrayerLiveActivity.swift`). ActivityKit iki tarafın aynı türü
/// kullanmasını ister; tür yalnızca uzantıda tanımlıyken uygulama
/// "Cannot find 'PrayerActivityAttributes' in scope" ile derlenmiyordu.
///
/// Uygulamanın en düşük iOS sürümü 15.0, `ActivityAttributes` ise 16.1 ile
/// geldiği için tür sürüm koşuluyla işaretli.
@available(iOS 16.1, *)
struct PrayerActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Kullanıcının dilinde vakit adı ("Akşam", "Maghrib", "المغرب").
    var prayerLabel: String
    /// Vaktin girdiği an.
    var prayerTime: Date
    /// Gösterilecekse şehir adı.
    var locationName: String?
  }

  /// Etkinlik boyunca değişmeyen ad.
  var appName: String
}
