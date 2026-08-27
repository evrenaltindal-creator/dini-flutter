import Flutter
import WidgetKit

final class WidgetSnapshotBridge {
  static let channelName = "dini/widget_snapshot"
  static let appGroup = "group.com.dini.diniFlutter"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "WidgetSnapshotBridge") else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any] else { result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are required", details: nil)); return }
      switch call.method {
      case "updateSnapshot":
        guard let raw = args["snapshot"] as? String, let data = raw.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { result(FlutterError(code: "INVALID_SNAPSHOT", message: "Snapshot JSON is invalid", details: nil)); return }
        let defaults = UserDefaults(suiteName: Self.appGroup)
        for (key, value) in object { defaults?.set(value, forKey: key) }
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
