import SwiftUI

/// Namaz Yolu'nun Apple Watch uygulaması.
///
/// Saat vakitleri kendisi HESAPLAMAZ: telefon aynı vakit motoruyla iki
/// haftalık çizelge çıkarıp WatchConnectivity ile gönderir (bkz.
/// `ios/Runner/WatchBridge.swift`, `lib/features/watch/`). Böylece saat ile
/// telefon arasında dakika farkı olmaz ve saat telefondan ayrı kaldığında da
/// iki hafta çalışır. Hiçbir şey sunucuya gitmez.
@main
struct DiniWatchApp: App {
  @StateObject private var store = ScheduleStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
    }
  }
}
