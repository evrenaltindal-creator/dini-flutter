import Flutter
import WidgetKit

final class WidgetSnapshotBridge {
  static let channelName = "dini/widget_snapshot"
  static let appGroup = "group.com.dini.diniFlutter"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "WidgetSnapshotBridge") else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "updateSnapshot":
        // Argüman yalnızca bu çağrıda gerekir. Eskiden bütün çağrıların
        // önünde isteniyordu; Dart `refreshWidgets` ve `clearSnapshot`'ı
        // argümansız çağırdığı için ikisi de her seferinde hata dönüyordu.
        guard
          let args = call.arguments as? [String: Any],
          let raw = args["snapshot"] as? String,
          let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
          result(FlutterError(code: "INVALID_SNAPSHOT", message: "Snapshot JSON is invalid", details: nil))
          return
        }
        let defaults = UserDefaults(suiteName: Self.appGroup)
        for (key, value) in object {
          // JSON'daki null burada NSNull olur ve UserDefaults onu KABUL
          // ETMEZ: "Attempt to insert non-property list object" istisnası
          // uygulamayı çökertir. Konum adı ayarı varsayılan olarak kapalı
          // olduğundan "locationName" her açılışta null geliyordu ve
          // TestFlight 1.0.0 (10) açılışta çöktü. Null, "bu değer artık
          // yok" demektir; anahtar silinir.
          if value is NSNull {
            defaults?.removeObject(forKey: key)
          } else {
            defaults?.set(value, forKey: key)
          }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DiniPrayerWidget")
        result(nil)
      case "clearSnapshot":
        UserDefaults(suiteName: Self.appGroup)?.removePersistentDomain(forName: Self.appGroup)
        WidgetCenter.shared.reloadTimelines(ofKind: "DiniPrayerWidget")
        result(nil)
      case "refreshWidgets":
        WidgetCenter.shared.reloadTimelines(ofKind: "DiniPrayerWidget")
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
