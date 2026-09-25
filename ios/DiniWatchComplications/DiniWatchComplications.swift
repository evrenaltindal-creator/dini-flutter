import SwiftUI
import WidgetKit

private let gold = Color(red: 0.95, green: 0.75, blue: 0.35)

/// Kadran göstergesi: sıradaki vakit, saati ve kalan süre.
///
/// Göstergenin kendi hesabı yoktur: saat uygulamasının telefondan aldığı
/// çizelgeyi App Group'tan okur (`SharedSchedule`). Çizelge 14 gündür;
/// telefon uzaktayken de gösterge iki hafta doğru kalır. Saat uygulaması
/// yeni çizelge alınca göstergeyi yeniden çizdirir.
@main
struct DiniWatchComplications: Widget {
  let kind = "DiniWatchComplications"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
      NextPrayerView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName(WatchFallbackText.text("appTitle"))
    .description(WatchFallbackText.text("watch.complication"))
    .supportedFamilies([
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCorner,
    ])
  }
}

/// Göstergenin bir anı.
struct NextPrayerEntry: TimelineEntry {
  let date: Date
  /// "Sıradaki" başlığı (telefonun dilinde).
  let heading: String
  /// Sıradaki vakit; çizelge yoksa ya da bittiyse nil.
  let label: String?
  /// Vaktin şehrin duvar saatindeki yazımı.
  let clock: String?
  let time: Date?
  /// Bir önceki vakit: dairesel göstergenin dolma aralığının başı.
  let previous: Date?
  /// Vakit yokken gösterilecek yazı.
  let message: String

  static func empty(at date: Date, message: String) -> NextPrayerEntry {
    NextPrayerEntry(
      date: date,
      heading: WatchFallbackText.text("watch.next"),
      label: nil,
      clock: nil,
      time: nil,
      previous: nil,
      message: message
    )
  }
}

struct NextPrayerProvider: TimelineProvider {
  func placeholder(in context: Context) -> NextPrayerEntry {
    let now = Date()
    return NextPrayerEntry(
      date: now,
      heading: WatchFallbackText.text("watch.next"),
      label: "—",
      clock: "--:--",
      time: now.addingTimeInterval(3600),
      previous: now,
      message: ""
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (NextPrayerEntry) -> Void) {
    let now = Date()
    completion(
      SharedSchedule.load().map { entry(for: $0, at: now) } ?? placeholder(in: context)
    )
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerEntry>) -> Void) {
    let now = Date()
    guard let schedule = SharedSchedule.load() else {
      completion(
        Timeline(
          entries: [.empty(at: now, message: WatchFallbackText.text("watch.empty"))],
          policy: .never
        )
      )
      return
    }
    // Her vakit geldiğinde bir sonrakine geçen anlar. Kalan süre
    // `Text(timerInterval:)` ile kendiliğinden işler; ara anlara gerek yok.
    // İki günlük an yeter: çizelge bitince zaman çizelgesi yenilenir.
    var entries = [entry(for: schedule, at: now)]
    let upcoming = schedule.days.flatMap { $0 }.filter { $0.time > now }.prefix(12)
    for moment in upcoming {
      entries.append(entry(for: schedule, at: moment.time))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func entry(for schedule: WatchSchedule, at date: Date) -> NextPrayerEntry {
    guard let next = schedule.next(after: date) else {
      return .empty(at: date, message: schedule.text("watch.stale"))
    }
    let all = schedule.days.flatMap { $0 }
    let previous = all.last { $0.time <= date }?.time
    return NextPrayerEntry(
      date: date,
      heading: schedule.text("watch.next"),
      label: next.label,
      clock: schedule.clock(next.time),
      time: next.time,
      previous: previous,
      message: ""
    )
  }
}

struct NextPrayerView: View {
  @Environment(\.widgetFamily) private var family
  let entry: NextPrayerEntry

  var body: some View {
    if let label = entry.label, let clock = entry.clock, let time = entry.time {
      switch family {
      case .accessoryCircular:
        circular(clock: clock, time: time)
      case .accessoryInline:
        Text("\(label) \(clock)")
      case .accessoryCorner:
        Text(clock)
          .font(.body.monospacedDigit())
          .widgetCurvesContent()
          .widgetLabel { Text(label) }
      default:
        rectangular(label: label, clock: clock, time: time)
      }
    } else {
      switch family {
      case .accessoryRectangular:
        Text(entry.message)
          .font(.footnote)
          .minimumScaleFactor(0.7)
      default:
        Text("—")
      }
    }
  }

  /// Önceki vakitten sıradakine dolan halka, ortasında vaktin saati.
  private func circular(clock: String, time: Date) -> some View {
    // Aralığın alt sınırı üst sınırı geçemez: ters aralık kurulursa
    // gösterge çöker (kilit ekranı sayacında aynı hata vardı).
    let start = min(entry.previous ?? entry.date, time.addingTimeInterval(-60))
    return ProgressView(timerInterval: start...time, countsDown: false) {
      EmptyView()
    } currentValueLabel: {
      Text(clock)
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .minimumScaleFactor(0.6)
    }
    .progressViewStyle(.circular)
    .tint(gold)
    .widgetAccentable()
  }

  private func rectangular(label: String, clock: String, time: Date) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(entry.heading)
        .font(.caption2)
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline) {
        Text(label)
          .font(.headline)
          .lineLimit(1)
        Spacer(minLength: 4)
        Text(clock)
          .font(.headline.monospacedDigit())
          .foregroundStyle(gold)
          .widgetAccentable()
      }
      Text(timerInterval: min(entry.date, time)...time, countsDown: true)
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
