import ActivityKit
import Flutter

/// Flutter'dan gelen canlı etkinlik çağrılarını ActivityKit'e bağlar.
///
/// Canlı etkinlik iOS 16.2 ve üzerinde vardır; daha eski sürümlerde ve
/// kullanıcı kilit ekranı etkinliklerini kapattığında çağrılar sessizce
/// başarısız olur. Uygulamanın geri kalanı bundan etkilenmez.
final class LiveActivityBridge {
  static let channelName = "dini/live_activity"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LiveActivityBridge") else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start", "update":
        guard
          let args = call.arguments as? [String: Any],
          let raw = args["state"] as? String,
          let state = decode(raw)
        else {
          result(FlutterError(code: "INVALID_STATE", message: "State JSON is invalid", details: nil))
          return
        }
        if #available(iOS 16.2, *) {
          Task { await apply(state); result(nil) }
        } else {
          result(nil)
        }
      case "end":
        if #available(iOS 16.2, *) {
          Task { await endAll(); result(nil) }
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func decode(_ raw: String) -> PrayerActivityAttributes.ContentState? {
    guard
      let data = raw.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let label = object["prayerLabel"] as? String,
      let time = object["prayerTime"] as? String,
      let date = ISO8601DateFormatter().date(from: time)
    else { return nil }
    return PrayerActivityAttributes.ContentState(
      prayerLabel: label,
      prayerTime: date,
      locationName: object["locationName"] as? String
    )
  }

  /// Süren etkinlik varsa günceller, yoksa başlatır.
  ///
  /// İkinci kez `request` çağırmak kilit ekranında ikinci bir sayaç açardı;
  /// Flutter tarafı da bunu aynayla engelliyor, burada ikinci bir koruma var.
  @available(iOS 16.2, *)
  private static func apply(_ state: PrayerActivityAttributes.ContentState) async {
    let activities = Activity<PrayerActivityAttributes>.activities
    if let current = activities.first {
      await current.update(ActivityContent(state: state, staleDate: state.prayerTime.addingTimeInterval(900)))
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    _ = try? Activity.request(
      attributes: PrayerActivityAttributes(appName: "Dini"),
      content: ActivityContent(state: state, staleDate: state.prayerTime.addingTimeInterval(900)),
      pushType: nil
    )
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<PrayerActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
