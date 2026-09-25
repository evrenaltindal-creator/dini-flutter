import Foundation
import WatchConnectivity
import WidgetKit

/// Telefondan gelen çizelgeyi alır ve saklar.
///
/// Telefon uygulama bağlamını günceller; saat uygulaması kapalıyken gelen son
/// bağlam oturum etkinleşince `receivedApplicationContext` içinde durur. Son
/// çizelge App Group'ta saklanır (`SharedSchedule`): telefon uzaktayken saat
/// açıldığında da vakitler görünür, kadran göstergesi de aynı çizelgeyi okur.
final class ScheduleStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var schedule: WatchSchedule?

  override init() {
    super.init()
    schedule = SharedSchedule.load()
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  private func accept(_ context: [String: Any]) {
    guard let schedule = WatchSchedule(payload: context) else { return }
    SharedSchedule.save(context)
    // Kadran göstergesi yeni çizelgeyle yeniden çizilsin.
    WidgetCenter.shared.reloadAllTimelines()
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
