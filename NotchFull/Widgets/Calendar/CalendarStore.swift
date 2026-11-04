import AppKit
import EventKit
import Observation

/// Today's and tomorrow's events from EventKit, kept current through store-change notifications.
@MainActor
@Observable
final class CalendarStore {
    enum Access {
        case notDetermined
        case granted
        /// Denied, restricted or write-only: the user must change it in System Settings.
        case unavailable
    }

    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: NSColor
    }

    private static let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")

    private let eventStore = EKEventStore()
    private(set) var access: Access
    private(set) var events: [Event] = []
    private(set) var lastError: String?
    private var isObserving = false

    init() {
        access = Self.currentAccess()
        if access == .granted {
            startObserving()
        }
    }

    func requestAccess() {
        // A @Sendable closure is not main-actor isolated, so EventKit may call it from any queue safely.
        let completion: @Sendable (Bool, (any Error)?) -> Void = { granted, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                }
                self.access = granted ? .granted : Self.currentAccess()
                if granted {
                    self.startObserving()
                }
            }
        }
        eventStore.requestFullAccessToEvents(completion: completion)
    }

    func openPrivacySettings() {
        guard let url = Self.privacySettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted, .writeOnly: .unavailable
        @unknown default: .unavailable
        }
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        reload()

        // The store lives for the app's lifetime, so these observers are never removed.
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func reload() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) else {
            lastError = "Could not compute the event date range."
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: endOfTomorrow, calendars: nil)
        events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                Event(
                    id: event.calendarItemIdentifier + "@" + event.startDate.ISO8601Format(),
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.color
                )
            }
        lastError = nil
    }
}
