import Foundation

struct UpcomingEvent: Equatable, Sendable {
    let title: String
    let start: Date
}

/// Announces each timed event once, when it is `calendarLeadMinutes` away.
@MainActor
final class UpcomingEventNotifier {
    private static let checkInterval: TimeInterval = 20

    private let calendar: CalendarStore
    private let settings: ActivitySettings
    private let onUpcoming: (UpcomingEvent) -> Void
    private var announcedEventIDs: Set<String> = []

    init(calendar: CalendarStore, settings: ActivitySettings, onUpcoming: @escaping (UpcomingEvent) -> Void) {
        self.calendar = calendar
        self.settings = settings
        self.onUpcoming = onUpcoming

        // The notifier lives for the app's lifetime, so the timer is never invalidated.
        Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        guard settings.showsUpcomingEvents, calendar.access == .granted else { return }
        let now = Date.now
        let lead = TimeInterval(settings.calendarLeadMinutes * 60)

        // Announce only right as an event enters the lead window. Events discovered deeper inside it (at launch,
        // or after the lead time changed) are skipped, so stale reminders never pile up.
        for event in calendar.events where !event.isAllDay && !announcedEventIDs.contains(event.id) {
            let remaining = event.start.timeIntervalSince(now)
            guard remaining > 0, remaining <= lead, remaining > lead - Self.checkInterval * 2 else { continue }
            announcedEventIDs.insert(event.id)
            onUpcoming(UpcomingEvent(title: event.title, start: event.start))
        }
    }
}
