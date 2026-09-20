import WidgetKit
import SwiftUI

private let appGroup = "group.com.dini.diniFlutter"

struct DiniWidgetEntry: TimelineEntry {
    let date: Date
    let nextName: String
    let nextTime: String
    let prayerLine: String
    let locationName: String?
    let scenePeriod: String
}

struct DiniWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiniWidgetEntry { DiniWidgetEntry(date: Date(), nextName: "Sıradaki namaz", nextTime: "—", prayerLine: "Fajr — · Dhuhr — · Asr —", locationName: nil, scenePeriod: "night") }
    func getSnapshot(in context: Context, completion: @escaping (DiniWidgetEntry) -> Void) { completion(Self.entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DiniWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroup)
        let now = Date()
        var dates = [now]
        for key in ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha", "nextPrayerTime"] {
            if let value = defaults?.string(forKey: key), let date = ISO8601DateFormatter().date(from: value), date > now { dates.append(date) }
        }
        let entries = dates.sorted().map { Self.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
    private static func entry(at date: Date = Date()) -> DiniWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        // Adlar Flutter tarafından kullanıcının dilinde gelir. Eski
        // sürümlerden kalan kayıtlarda etiket olmayabilir; o zaman anahtarın
        // kendisi kullanılır.
        let nextName = defaults?.string(forKey: "nextPrayerLabel")
            ?? defaults?.string(forKey: "nextPrayer")
            ?? "Sıradaki namaz"
        let nextTime = format(defaults?.string(forKey: "nextPrayerTime"))
        let line = ["fajr", "dhuhr", "asr", "maghrib", "isha"].map { key in
            let label = defaults?.string(forKey: "label_\(key)") ?? key.capitalized
            return "\(label) \(format(defaults?.string(forKey: key)))"
        }.joined(separator: "  ·  ")
        return DiniWidgetEntry(date: date, nextName: nextName, nextTime: nextTime, prayerLine: line, locationName: defaults?.string(forKey: "locationName"), scenePeriod: defaults?.string(forKey: "scenePeriod") ?? "night")
    }
    private static func format(_ iso: String?) -> String { guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "—" }; return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short) }
}

struct DiniWidgetView: View {
    let entry: DiniWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if #available(iOS 16.0, *), isAccessory {
            // Kilit ekranı boyutları tek renktir ve çok küçüktür; ana ekran
            // düzeni buraya sığmaz, zemin de çizilmez.
            accessory.containerBackground(for: .widget) { Color.clear }
        } else {
            home.containerBackground(for: .widget) { Color(red: 0.06, green: 0.15, blue: 0.23) }
        }
    }

    private var isAccessory: Bool {
        guard #available(iOS 16.0, *) else { return false }
        return family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.nextName).font(.caption).foregroundStyle(.secondary)
            Text(entry.nextTime).font(.title.bold()).foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.35))
            if family == .systemMedium { Text(entry.prayerLine).font(.caption2).minimumScaleFactor(0.6) }
            if let location = entry.locationName, !location.isEmpty { Text(location).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    @available(iOS 16.0, *)
    @ViewBuilder private var accessory: some View {
        switch family {
        case .accessoryInline:
            // Tek satır: ad ve saat yan yana sığmalı.
            Text("\(entry.nextName) \(entry.nextTime)")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.nextTime).font(.headline).minimumScaleFactor(0.6)
                Text(entry.nextName).font(.system(size: 9)).minimumScaleFactor(0.5).lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nextName).font(.caption)
                Text(entry.nextTime).font(.title3.bold())
                if let location = entry.locationName, !location.isEmpty {
                    Text(location).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DiniPrayerWidget: Widget {
    let kind = "DiniPrayerWidget"

    /// Desteklenen boyutlar. Kilit ekranı boyutları (accessory*) iOS 16 ile
    /// gelir; eski sürümlerde yalnızca ana ekran boyutları kalır.
    static var families: [WidgetFamily] {
        var result: [WidgetFamily] = [.systemSmall, .systemMedium]
        if #available(iOS 16.0, *) {
            result.append(contentsOf: [.accessoryCircular, .accessoryRectangular, .accessoryInline])
        }
        return result
    }
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: DiniWidgetProvider()) { entry in DiniWidgetView(entry: entry) }.configurationDisplayName("Namaz Yolu").description("Sıradaki namazı ve günlük vakitleri gösterir.").supportedFamilies(Self.families) }
}

@main
struct DiniWidgetBundle: WidgetBundle {
    var body: some Widget {
        DiniPrayerWidget()
        // Canlı etkinlik iOS 16.2 ile gelir; eski sürümlerde paket yalnızca
        // ana ekran widget'ını taşır.
        if #available(iOS 16.2, *) { PrayerLiveActivity() }
    }
}
