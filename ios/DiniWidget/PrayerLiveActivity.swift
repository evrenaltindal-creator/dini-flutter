import ActivityKit
import SwiftUI
import WidgetKit

/// Kilit ekranındaki ve Dynamic Island'daki sıradaki vakit.
///
/// Metinler Flutter tarafından hazır çevrilmiş gelir; uzantının uygulamanın
/// çeviri haritasına erişimi yoktur ve burada çeviri yapılırsa kilit ekranı
/// uygulamanın dilinden bağımsız görünür.
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

@available(iOS 16.2, *)
struct PrayerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
      // Kilit ekranı görünümü.
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.prayerLabel)
            .font(.headline)
          if let city = context.state.locationName {
            Text(city)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          // Sayaç sistem tarafından işletilir: uygulama her dakika
          // güncelleme göndermek zorunda kalmaz, arka planda uyusa bile
          // kilit ekranındaki süre doğru akar.
          Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
            .font(.title2.monospacedDigit())
            .multilineTextAlignment(.trailing)
          Text(context.state.prayerTime, style: .time)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(16)
      .activityBackgroundTint(Color(red: 0.04, green: 0.24, blue: 0.23))
      .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.state.prayerLabel).font(.headline).padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
            .font(.title3.monospacedDigit())
            .multilineTextAlignment(.trailing)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if let city = context.state.locationName {
            Text(city).font(.caption).foregroundStyle(.secondary)
          }
        }
      } compactLeading: {
        Image(systemName: "moon.stars")
      } compactTrailing: {
        Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
          .monospacedDigit()
          .frame(maxWidth: 48)
      } minimal: {
        Image(systemName: "moon.stars")
      }
    }
  }
}
