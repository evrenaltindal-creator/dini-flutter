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

/// Widget'taki kısayol düğmelerinin açtığı adresler. Uygulama bu adresi
/// (`namazyolu://open/<sayfa>`) Flutter'ın yönlendiricisine verir; yol,
/// go_router'daki rotadır. Şema Runner'ın Info.plist'inde tanımlıdır.
enum AppLink {
    static let scheme = "namazyolu"
    static func url(_ route: String) -> URL { URL(string: "\(scheme)://open/\(route)")! }
}

/// Günün beş vakti, ekranda sırasıyla: üstte üç, altta iki.
private let dailyPrayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

/// Sıradaki vakit seçilirken güneş de sayılır; uygulama da öyle yapar
/// (`nextPrayerState`).
private let orderedPrayers = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]

struct DiniWidgetEntry: TimelineEntry {
    let date: Date
    let nextName: String
    let nextTime: String
    /// Sıradaki vaktin anı; geri sayım buna göre işler.
    let nextDate: Date?
    /// (ad, saat) — günün beş vakti.
    let prayers: [(String, String)]
    let remaining: String
    let tasbih: String
    let qibla: String
    let tracker: String
    let scenePeriod: String
}

struct DiniWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiniWidgetEntry {
        DiniWidgetEntry(date: Date(), nextName: "Sıradaki namaz", nextTime: "—", nextDate: nil, prayers: dailyPrayers.map { ($0.capitalized, "—") }, remaining: "", tasbih: "Tesbih", qibla: "Kıble", tracker: "Takip", scenePeriod: "night")
    }
    func getSnapshot(in context: Context, completion: @escaping (DiniWidgetEntry) -> Void) { completion(Self.entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DiniWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroup)
        let now = Date()
        var dates = [now]
        // Her vakit girişinde yeni bir kayıt: sıradaki vakit ve geri sayım
        // uygulama açılmadan da bir sonrakine geçer.
        for key in orderedPrayers + ["tomorrowFajr", "nextPrayerTime"] {
            if let date = IsoDate.parse(defaults?.string(forKey: key)), date > now { dates.append(date) }
        }
        let entries = Set(dates).sorted().map { Self.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func entry(at date: Date = Date()) -> DiniWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        // Adlar Flutter tarafından kullanıcının dilinde gelir. Eski
        // sürümlerden kalan kayıtlarda etiket olmayabilir; o zaman anahtarın
        // kendisi kullanılır.
        func label(_ key: String, _ fallback: String) -> String { defaults?.string(forKey: "label_\(key)") ?? fallback }

        // Sıradaki vakit bu kaydın anına göre seçilir: bugünün vakitleri,
        // yatsıdan sonra yarının sabahı. Hiçbiri yoksa uygulamanın son
        // yazdığı sıradaki vakit.
        var next: (key: String, date: Date)?
        for key in orderedPrayers {
            if let time = IsoDate.parse(defaults?.string(forKey: key)), time > date { next = (key, time); break }
        }
        if next == nil, let fajr = IsoDate.parse(defaults?.string(forKey: "tomorrowFajr")), fajr > date {
            next = ("fajr", fajr)
        }
        if next == nil, let key = defaults?.string(forKey: "nextPrayer"),
           let time = IsoDate.parse(defaults?.string(forKey: "nextPrayerTime")), time > date {
            next = (key, time)
        }

        let nextName = next.map { label($0.key, $0.key.capitalized) }
            ?? defaults?.string(forKey: "nextPrayerLabel")
            ?? "Sıradaki namaz"
        let prayers = dailyPrayers.map { key in (label(key, key.capitalized), format(defaults?.string(forKey: key))) }
        return DiniWidgetEntry(
            date: date,
            nextName: nextName,
            nextTime: next.map { format($0.date) } ?? "—",
            nextDate: next?.date,
            prayers: prayers,
            remaining: label("remaining", ""),
            tasbih: label("tasbih", "Tesbih"),
            qibla: label("qibla", "Kıble"),
            tracker: label("tracker", "Takip"),
            scenePeriod: defaults?.string(forKey: "scenePeriod") ?? "night"
        )
    }

    private static func format(_ date: Date) -> String { DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short) }
    private static func format(_ iso: String?) -> String { guard let date = IsoDate.parse(iso) else { return "—" }; return format(date) }
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

    // Konum gösterilmez (kullanıcı kararı); yerine uygulamanın sık açılan
    // üç bölümüne kısayol durur. Kısayollar yalnızca orta boyda: küçük
    // widget'ta tek dokunma alanı vardır.
    private var home: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 7 : 4) {
            Text(entry.nextName).font(.caption).foregroundStyle(Self.cream.opacity(0.78))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.nextTime).font(.title.bold()).foregroundStyle(Self.gold)
                if family == .systemMedium { countdown }
            }
            if family != .systemMedium { countdown }
            if family == .systemMedium {
                prayerGrid
                shortcuts
            }
        }
    }

    /// "2:10:05 kaldı": sistem saniye saniye kendisi günceller.
    @ViewBuilder private var countdown: some View {
        if let next = entry.nextDate, next > entry.date {
            HStack(spacing: 4) {
                Text(next, style: .timer).font(.caption.monospacedDigit()).foregroundStyle(Self.cream)
                Text(entry.remaining).font(.caption).foregroundStyle(Self.cream.opacity(0.78))
            }
            .fixedSize()
        }
    }

    /// Vakitler iki satırda, ikisi de yatayda ortalı: üstte sabah, öğle,
    /// ikindi; altta akşam, yatsı.
    private var prayerGrid: some View {
        VStack(spacing: 3) {
            prayerRow(Array(entry.prayers.prefix(3)))
            prayerRow(Array(entry.prayers.suffix(from: 3)))
        }
        .frame(maxWidth: .infinity)
    }

    private func prayerRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                Text("\(items[index].0) \(items[index].1)").font(.caption2).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(Self.cream)
            }
        }
    }

    private var shortcuts: some View {
        HStack(spacing: 8) {
            shortcut(entry.tasbih, symbol: "hand.point.up.left", route: "tasbih")
            shortcut(entry.qibla, symbol: "safari", route: "qibla")
            shortcut(entry.tracker, symbol: "checkmark.circle", route: "tracker")
        }
        .frame(maxWidth: .infinity)
    }

    /// Dokununca uygulama o bölümde açılır.
    private func shortcut(_ title: String, symbol: String, route: String) -> some View {
        Link(destination: AppLink.url(route)) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption2).foregroundStyle(Self.gold)
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(Self.cream)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Self.cream.opacity(0.12)))
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
                if let next = entry.nextDate, next > entry.date {
                    Text(next, style: .timer).font(.caption2.monospacedDigit())
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
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: DiniWidgetProvider()) { entry in DiniWidgetView(entry: entry) }.configurationDisplayName("Namaz Yolu").description("Sıradaki namaz, kalan süre, günün vakitleri ve kısayollar.").supportedFamilies(Self.families) }
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
