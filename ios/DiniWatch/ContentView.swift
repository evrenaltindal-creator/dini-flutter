import SwiftUI

private let gold = Color(red: 0.95, green: 0.75, blue: 0.35)

struct ContentView: View {
  @EnvironmentObject private var store: ScheduleStore

  var body: some View {
    // Sıradaki vakit geçince ekran kendiliğinden bir sonrakine geçsin diye
    // görünüm yarım dakikada bir yeniden hesaplanır.
    TimelineView(.periodic(from: .now, by: 30)) { context in
      content(now: context.date)
    }
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
