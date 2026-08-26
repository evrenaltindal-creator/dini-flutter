import WidgetKit
import SwiftUI

private let appGroup = "group.com.dini.dini_flutter"

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
        let nextName = defaults?.string(forKey: "nextPrayer") ?? "Sıradaki namaz"
        let nextTime = format(defaults?.string(forKey: "nextPrayerTime"))
        let line = ["fajr", "dhuhr", "asr", "maghrib", "isha"].map { key in "\(key.capitalized) \(format(defaults?.string(forKey: key)))" }.joined(separator: "  ·  ")
        return DiniWidgetEntry(date: date, nextName: nextName, nextTime: nextTime, prayerLine: line, locationName: defaults?.string(forKey: "locationName"), scenePeriod: defaults?.string(forKey: "scenePeriod") ?? "night")
    }
    private static func format(_ iso: String?) -> String { guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "—" }; return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short) }
}

struct DiniWidgetView: View {
    let entry: DiniWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.nextName).font(.caption).foregroundStyle(.secondary)
            Text(entry.nextTime).font(.title.bold()).foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.35))
            if family == .systemMedium { Text(entry.prayerLine).font(.caption2).minimumScaleFactor(0.6) }
            if let location = entry.locationName, !location.isEmpty { Text(location).font(.caption2).foregroundStyle(.secondary) }
        }.containerBackground(for: .widget) { Color(red: 0.06, green: 0.15, blue: 0.23) }
    }
}

struct DiniPrayerWidget: Widget {
    let kind = "DiniPrayerWidget"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: DiniWidgetProvider()) { entry in DiniWidgetView(entry: entry) }.configurationDisplayName("Dini Namaz Vakitleri").description("Sıradaki namazı ve günlük vakitleri gösterir.").supportedFamilies([.systemSmall, .systemMedium]) }
}

@main
struct DiniWidgetBundle: WidgetBundle { var body: some Widget { DiniPrayerWidget() } }
