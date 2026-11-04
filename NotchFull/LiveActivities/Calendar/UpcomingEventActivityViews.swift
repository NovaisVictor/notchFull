import SwiftUI

struct UpcomingEventLeadingView: View {
    @State private var appeared = false

    var body: some View {
        Image(systemName: "calendar.badge.clock")
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 16))
            .foregroundStyle(.blue)
            .symbolEffect(.bounce, value: appeared)
            .onAppear { appeared = true }
    }
}

struct UpcomingEventTrailingView: View {
    let event: UpcomingEvent

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.countdown(to: event.start, from: context.date))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .help(event.title)
    }

    static func countdown(to start: Date, from now: Date) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 0 ? "Now" : "\(minutes)m"
    }
}
