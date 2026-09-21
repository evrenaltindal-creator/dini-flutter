import WidgetKit
import SwiftUI

private let appGroup = "group.com.dini.diniFlutter"

/// Flutter'ın yazdığı ISO 8601 metnini çözer.
///
/// Dart tarafı TZDateTime yazıyor: "2026-09-21T05:17:00.000+0300".
/// `ISO8601DateFormatter()` varsayılan seçeneklerle saliseyi KABUL ETMEZ ve
/// nil döner; widget da bütün vakitleri "—" gösterir. Aynı çözümleyici
/// `LiveActivityBridge.swift` içinde de var — iki dosya ayrı Xcode
/// hedeflerinde derlendiği için kopya; biri değişirse diğeri de değişmeli
/// (`widget_snapshot_test.dart` ve `live_activity_test.dart` ikisini de
/// bekçiliyor).
enum IsoDate {
    private static let formatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [fractional, plain]
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}

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
            if let date = IsoDate.parse(defaults?.string(forKey: key)), date > now { dates.append(date) }
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
    private static func format(_ iso: String?) -> String { guard let date = IsoDate.parse(iso) else { return "—" }; return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short) }
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

    // Ana ekran boyutunun zemini HER GÖRÜNÜMDE koyudur (aşağıdaki
    // containerBackground). `.secondary` ve varsayılan yazı rengi ise
    // sistemin görünümünü izler: telefon aydınlık kipteyken koyu gri olur ve
    // koyu zeminin üstünde okunmaz. Widget telefonda tam olarak böyle
    // görünüyordu, bu yüzden renkler burada açıkça veriliyor.
    private static let cream = Color(red: 0.96, green: 0.94, blue: 0.89)
    private static let gold = Color(red: 0.95, green: 0.75, blue: 0.35)

    private var home: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.nextName).font(.caption).foregroundStyle(Self.cream.opacity(0.78))
            Text(entry.nextTime).font(.title.bold()).foregroundStyle(Self.gold)
            if family == .systemMedium { Text(entry.prayerLine).font(.caption2).minimumScaleFactor(0.6).foregroundStyle(Self.cream) }
            if let location = entry.locationName, !location.isEmpty { Text(location).font(.caption2).foregroundStyle(Self.cream.opacity(0.6)) }
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
