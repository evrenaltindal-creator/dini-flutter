import Flutter
import WatchConnectivity

/// Flutter'ın hesapladığı vakit çizelgesini Apple Watch'a iletir.
///
/// Saat vakitleri kendisi hesaplamaz: telefon iki haftalık çizelgeyi
/// WatchConnectivity'nin **uygulama bağlamıyla** gönderir. Bağlam her zaman
/// son değeri tutar; saat o sırada uzaktaysa ya da uygulaması kapalıysa bile
/// yakına gelince teslim edilir. Hiçbir şey sunucuya gitmez, konum
/// koordinatları da gönderilmez — yalnızca vakitler ve adları.
///
/// Oturum eşzamansız etkinleşir; etkinleşmeden önce gönderilen çizelge
/// bekletilir ve etkinleşince yollanır. Saat eşleşmemişse ya da saat
/// uygulaması kurulu değilse çağrı sessizce başarılı döner: saat ikincil bir
/// yüzeydir ve uygulamanın açılışını durdurmamalıdır.
final class WatchBridge: NSObject, WCSessionDelegate {
  static let channelName = "dini/watch"
  static let shared = WatchBridge()

  /// Oturum etkinleşmeden gelen son çizelge.
  private var pending: [String: Any]?

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "WatchBridge") else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    shared.activate()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "updateSchedule":
        guard
          let args = call.arguments as? [String: Any],
          let raw = args["schedule"] as? String,
          let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
          result(FlutterError(code: "INVALID_SCHEDULE", message: "Schedule JSON is invalid", details: nil))
          return
        }
        shared.send(object)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  private func send(_ schedule: [String: Any]) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      // Etkinleşince `activationDidCompleteWith` gönderir.
      pending = schedule
      return
    }
    // Eşleşmiş saat yoksa ya da saat uygulaması kurulu değilse gönderecek
    // bir yer yok; bu bir hata değildir.
    guard session.isPaired, session.isWatchAppInstalled else { return }
    // Bağlam property-list ister. Dart tarafı null ve tarih metni
    // göndermez (bkz. `WatchSchedule.toPayload`); NSNull burada uygulamayı
    // çökertmezdi ama `updateApplicationContext` hata fırlatırdı.
    try? session.updateApplicationContext(schedule)
  }

  // MARK: - WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, let schedule = pending else { return }
    // Temsilci arka plan kuyruğunda çağrılır; bekleyen değer ana kuyrukta
    // yazıldığı için okuma ve gönderim de orada yapılır.
    DispatchQueue.main.async {
      self.pending = nil
      self.send(schedule)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Kullanıcı başka bir saate geçtiğinde oturum yeniden etkinleştirilmeli,
    // yoksa yeni saate hiçbir şey gitmez.
    session.activate()
  }
}
