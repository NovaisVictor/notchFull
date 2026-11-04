import SwiftUI

struct CalendarWidgetView: View {
    private static let visibleEventCount = 3

    let store: CalendarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            switch store.access {
            case .notDetermined:
                message("Show your upcoming events here.", action: "Allow access") { store.requestAccess() }
            case .unavailable:
                message("Calendar access is off.", action: "Open Settings") { store.openPrivacySettings() }
            case .granted:
                eventList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var eventList: some View {
        TimelineView(.everyMinute) { context in
            let upcoming = store.events
                .filter { $0.end > context.date }
                .prefix(Self.visibleEventCount)

            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if upcoming.isEmpty {
                Text("Nothing else today or tomorrow.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(upcoming) { event in
                        EventRow(event: event, now: context.date)
                    }
                }
            }
        }
    }

    private func message(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
            Button(action, action: perform)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

private struct EventRow: View {
    let event: CalendarStore.Event
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(nsColor: event.color))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(timeDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var timeDescription: String {
        let day = Calendar.current.isDateInToday(event.start) ? "" : "Tomorrow · "
        if event.isAllDay { return day + "All day" }
        if event.start <= now { return "Now · until " + event.end.formatted(date: .omitted, time: .shortened) }
        return day + event.start.formatted(date: .omitted, time: .shortened)
    }
}
