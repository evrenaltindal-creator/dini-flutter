import SwiftUI
import WatchKit

private let gold = Color(red: 0.95, green: 0.75, blue: 0.35)

/// İki sayfa, Digital Crown'la ya da kaydırarak aşağı-yukarı: vakitler ve
/// tesbih.
struct ContentView: View {
  @EnvironmentObject private var store: ScheduleStore

  var body: some View {
    TabView {
      // Sıradaki vakit geçince ekran kendiliğinden bir sonrakine geçsin
      // diye görünüm yarım dakikada bir yeniden hesaplanır.
      TimelineView(.periodic(from: .now, by: 30)) { context in
        content(now: context.date)
      }
      TasbihView(text: text)
    }
    .tabViewStyle(.verticalPage)
  }

  /// Metin telefondan gelir; saat hiç eşleşmediyse yedek tablodan.
  private func text(_ key: String) -> String {
    store.schedule?.text(key) ?? WatchFallbackText.text(key)
  }

  @ViewBuilder
  private func content(now: Date) -> some View {
    if let schedule = store.schedule, let next = schedule.next(after: now) {
      ScheduleView(schedule: schedule, next: next, now: now)
    } else if let schedule = store.schedule {
      MessageView(text: schedule.text("watch.stale"))
    } else {
      MessageView(text: WatchFallbackText.text("watch.empty"))
    }
  }
}

private struct ScheduleView: View {
  let schedule: WatchSchedule
  let next: PrayerMoment
  let now: Date

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 2) {
          Text(schedule.text("watch.next"))
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text(next.label)
            .font(.headline)
          Text(schedule.clock(next.time))
            .font(.title2.monospacedDigit())
            .foregroundStyle(gold)
          // Alt sınır vakti geçemez: ters aralık kurulursa uygulama çöker
          // (kilit ekranı sayacında aynı hata vardı).
          Text(timerInterval: min(now, next.time)...next.time, countsDown: true)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }

      Section(schedule.text("watch.today")) {
        ForEach(schedule.day(of: next)) { moment in
          HStack {
            Text(moment.label)
            Spacer()
            Text(schedule.clock(moment.time))
              .monospacedDigit()
          }
          .foregroundStyle(moment == next ? gold : .primary)
        }
      }

      if let city = schedule.locationName {
        Text(city)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct MessageView: View {
  let text: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "moon.stars")
        .font(.title2)
        .foregroundStyle(gold)
      Text(text)
        .font(.footnote)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

/// Saatte tesbih: ekrana dokun ya da Digital Crown'u çevir, her sayışta
/// bilek hafifçe titrer; hedefe (33, 99) varınca belirgin bir titreşim ve
/// yeni tur başlar. Sayı saatte saklanır, uygulama kapansa da kalır;
/// telefondaki tesbihten ayrıdır.
private struct TasbihView: View {
  let text: (String) -> String

  @AppStorage("tasbih.count") private var count = 0
  /// 0 = hedefsiz.
  @AppStorage("tasbih.target") private var target = 33
  @State private var crown = 0.0
  @State private var confirmReset = false

  private static let targets = [33, 99, 0]

  /// Bu turda kaçıncı; tur tamamlanınca hedefin kendisi görünür.
  private var inRound: Int {
    guard target > 0, count > 0 else { return count }
    let rest = count % target
    return rest == 0 ? target : rest
  }

  var body: some View {
    VStack(spacing: 6) {
      Button(action: increment) {
        ZStack {
          Circle().stroke(gold.opacity(0.25), lineWidth: 6)
          if target > 0 {
            Circle()
              .trim(from: 0, to: CGFloat(inRound) / CGFloat(target))
              .stroke(gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
              .rotationEffect(.degrees(-90))
          }
          VStack(spacing: 0) {
            Text("\(count)")
              .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
              .minimumScaleFactor(0.5)
            if target > 0 {
              Text("\(inRound) / \(target)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(gold)
            }
          }
        }
        .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(text("home.tasbih"))
      .accessibilityValue("\(count)")

      HStack(spacing: 6) {
        Button {
          let index = Self.targets.firstIndex(of: target) ?? 0
          target = Self.targets[(index + 1) % Self.targets.count]
        } label: {
          Text(target > 0 ? "\(text("tasbih.target")) \(target)" : "\(text("tasbih.target")) ∞")
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        Button(role: .destructive) {
          confirmReset = true
        } label: {
          Image(systemName: "arrow.counterclockwise")
        }
        .accessibilityLabel(text("tasbih.reset"))
      }
      .controlSize(.small)
    }
    .navigationTitle(text("home.tasbih"))
    .focusable()
    // Crown'un her bir tık çevrilişi bir sayış; geri çevirmek saymaz.
    .digitalCrownRotation(
      $crown, from: 0, through: 1_000_000, by: 1,
      sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false
    )
    .onChange(of: crown) { old, new in
      if Int(new) > Int(old) { increment() }
    }
    .confirmationDialog(text("tasbih.reset"), isPresented: $confirmReset) {
      Button(text("tasbih.reset"), role: .destructive) { count = 0 }
    }
  }

  private func increment() {
    count += 1
    let completed = target > 0 && count % target == 0
    WKInterfaceDevice.current().play(completed ? .success : .click)
  }
}
