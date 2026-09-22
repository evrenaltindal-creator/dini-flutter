import ActivityKit
import Flutter

/// Flutter'dan gelen canlı etkinlik çağrılarını ActivityKit'e bağlar.
///
/// Canlı etkinlik iOS 16.2 ve üzerinde vardır; daha eski sürümlerde ve
/// kullanıcı kilit ekranı etkinliklerini kapattığında çağrılar sessizce
/// başarısız olur. Uygulamanın geri kalanı bundan etkilenmez.
/// Flutter'ın yazdığı ISO 8601 metnini çözer.
///
/// Dart "2026-09-21T05:17:00.000+0300" gönderiyor; `ISO8601DateFormatter()`
/// varsayılan seçeneklerle saliseyi kabul etmez ve nil döner — köprü de
/// INVALID_STATE verip kilit ekranında hiçbir şey açmazdı. Aynı çözümleyici
/// uzantı hedefindeki `DiniWidget.swift` içinde de var (ayrı hedefler).
enum LiveActivityIsoDate {
  private static let formatters: [ISO8601DateFormatter] = {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return [fractional, plain]
  }()

  static func parse(_ raw: String) -> Date? {
    for formatter in formatters {
      if let date = formatter.date(from: raw) { return date }
    }
    return nil
  }
}

final class LiveActivityBridge {
  static let channelName = "dini/live_activity"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LiveActivityBridge") else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start", "update":
        // Etkinlik türü iOS 16.2 öncesinde yok; çözümlemeden önce sınanır,
        // yoksa uygulama hedefi (en düşük sürüm 15.0) derlenmez.
        guard #available(iOS 16.2, *) else {
          result(nil)
          return
        }
        guard
          let args = call.arguments as? [String: Any],
          let raw = args["state"] as? String,
          let state = decode(raw)
        else {
          result(FlutterError(code: "INVALID_STATE", message: "State JSON is invalid", details: nil))
          return
        }
        Task { await apply(state); result(nil) }
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

  @available(iOS 16.2, *)
  private static func decode(_ raw: String) -> PrayerActivityAttributes.ContentState? {
    guard
      let data = raw.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let label = object["prayerLabel"] as? String,
      let time = object["prayerTime"] as? String,
      let date = LiveActivityIsoDate.parse(time)
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
      attributes: PrayerActivityAttributes(appName: "Namaz Yolu"),
      content: ActivityContent(state: state, staleDate: state.prayerTime.addingTimeInterval(900)),
      pushType: nil
    )
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<PrayerActivityAttributes>.activities {
      await activity.end(
        nil as ActivityContent<PrayerActivityAttributes.ContentState>?,
        dismissalPolicy: .immediate
      )
    }
  }
}
