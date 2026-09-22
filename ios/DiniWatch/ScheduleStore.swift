import Foundation
import WatchConnectivity

/// Telefondan gelen çizelgeyi alır ve saklar.
///
/// Telefon uygulama bağlamını günceller; saat uygulaması kapalıyken gelen son
/// bağlam oturum etkinleşince `receivedApplicationContext` içinde durur. Son
/// çizelge saatin kendi `UserDefaults`'ında tutulur: telefon uzaktayken saat
/// açıldığında da vakitler görünür.
final class ScheduleStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var schedule: WatchSchedule?

  private static let storageKey = "dini.watch.schedule"

  override init() {
    super.init()
    schedule = Self.loadSaved()
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  private static func loadSaved() -> WatchSchedule? {
    guard
      let data = UserDefaults.standard.data(forKey: storageKey),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return WatchSchedule(payload: object)
  }

  private func accept(_ context: [String: Any]) {
    guard let schedule = WatchSchedule(payload: context) else { return }
    // Veri (Data) property-list türüdür; sözlüğün kendisi değil, JSON'u
    // saklanır. Böylece içindeki bir değer UserDefaults'u asla kıramaz.
    if JSONSerialization.isValidJSONObject(context),
      let data = try? JSONSerialization.data(withJSONObject: context)
    {
      UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
    DispatchQueue.main.async { self.schedule = schedule }
  }

  // MARK: - WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let context = session.receivedApplicationContext
    if !context.isEmpty { accept(context) }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    accept(applicationContext)
  }
}
