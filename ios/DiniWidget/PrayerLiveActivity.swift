import ActivityKit
import SwiftUI
import WidgetKit

/// Kilit ekranındaki ve Dynamic Island'daki sıradaki vakit.
///
/// Metinler Flutter tarafından hazır çevrilmiş gelir; uzantının uygulamanın
/// çeviri haritasına erişimi yoktur ve burada çeviri yapılırsa kilit ekranı
/// uygulamanın dilinden bağımsız görünür. `PrayerActivityAttributes`
/// ayrı dosyadadır, çünkü uygulama hedefinde de derlenmesi gerekir.
@available(iOS 16.2, *)
struct PrayerLiveActivity: Widget {
  // Kilit ekranı görünümünün zemini koyu (activityBackgroundTint).
  // `.secondary` ve varsayılan yazı rengi ise sistemin görünümünü izler;
  // telefon aydınlık kipteyken koyu zemine koyu yazı düşerdi (ana ekran
  // widget'ında tam olarak bu oldu). Renkler bu yüzden açıkça veriliyor.
  private static let cream = Color(red: 0.96, green: 0.94, blue: 0.89)
  private static let gold = Color(red: 0.95, green: 0.75, blue: 0.35)

  /// Geri sayımın aralığı.
  ///
  /// Etkinlik vakit girdikten sonra da bir süre (Flutter tarafında
  /// `liveActivityLingerMinutes`) ekranda kalır. O sırada şimdiki an
  /// vakitten büyüktür ve "şimdi...vakit" ters bir aralık olur — Swift ters
  /// `ClosedRange` kurulunca uzantıyı çökertir. Alt sınır vakti geçemez;
  /// süre dolunca sayaç sıfırda durur.
  static func countdown(to prayerTime: Date, now: Date = Date()) -> ClosedRange<Date> {
    min(now, prayerTime)...prayerTime
  }

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
      // Kilit ekranı görünümü.
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.prayerLabel)
            .font(.headline)
            .foregroundStyle(Self.cream)
          if let city = context.state.locationName {
            Text(city)
              .font(.caption)
              .foregroundStyle(Self.cream.opacity(0.7))
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          // Sayaç sistem tarafından işletilir: uygulama her dakika
          // güncelleme göndermek zorunda kalmaz, arka planda uyusa bile
          // kilit ekranındaki süre doğru akar.
          Text(timerInterval: Self.countdown(to: context.state.prayerTime), countsDown: true)
            .font(.title2.monospacedDigit())
            .foregroundStyle(Self.gold)
            .multilineTextAlignment(.trailing)
          Text(context.state.prayerTime, style: .time)
            .font(.caption)
            .foregroundStyle(Self.cream.opacity(0.7))
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
          Text(timerInterval: Self.countdown(to: context.state.prayerTime), countsDown: true)
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
        Text(timerInterval: Self.countdown(to: context.state.prayerTime), countsDown: true)
          .monospacedDigit()
          .frame(maxWidth: 48)
      } minimal: {
        Image(systemName: "moon.stars")
      }
    }
  }
}
