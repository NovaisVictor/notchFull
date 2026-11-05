import Foundation
import Observation

/// Focus/break timer. Time is never counted down tick by tick: the state stores when the phase ends (or how much
/// was left when paused) and everything else is derived, so the timer survives sleep and app restarts.
@MainActor
@Observable
final class PomodoroTimer {
    enum Phase: String, Codable {
        case focus
        /// The break between focus sessions (`break` is a Swift keyword).
        case rest
    }

    enum State: Codable, Equatable {
        case idle
        case running(end: Date)
        case paused(remaining: TimeInterval)
        case stopwatchRunning(start: Date)
        case stopwatchPaused(elapsed: TimeInterval)
    }

    private struct Snapshot: Codable {
        let phase: Phase
        let state: State
        let usesStopwatch: Bool
        let taskID: UUID?
        let taskTitle: String?
        let sessionDuration: TimeInterval?
    }

    private static let defaultsKey = "pomodoro.state"

    private(set) var phase: Phase = .focus
    private(set) var state: State = .idle
    /// Counts up without an end instead of counting down.
    private(set) var usesStopwatch = false
    /// The to-do this focus session is for, when started from a task.
    private(set) var taskID: UUID?
    private(set) var taskTitle: String?
    private(set) var lastError: String?

    @ObservationIgnored private let settings: PomodoroSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var completion: Task<Void, Never>?

    init(settings: PomodoroSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        restore()
    }

    var isActive: Bool { state != .idle }

    var isRunning: Bool {
        switch state {
        case .running, .stopwatchRunning: true
        case .idle, .paused, .stopwatchPaused: false
        }
    }

    /// Seconds to show: remaining for the countdown, elapsed for the stopwatch, the full length when idle.
    func displayedTime(at date: Date) -> TimeInterval {
        switch state {
        case .idle: usesStopwatch ? 0 : phaseDuration
        case let .running(end): max(end.timeIntervalSince(date), 0)
        case let .paused(remaining): remaining
        case let .stopwatchRunning(start): date.timeIntervalSince(start)
        case let .stopwatchPaused(elapsed): elapsed
        }
    }

    /// 0...1 of the countdown completed; `nil` for the stopwatch, which has no end.
    func progress(at date: Date) -> Double? {
        switch state {
        case .idle:
            return usesStopwatch ? nil : 0
        case .running, .paused:
            guard let total = sessionDuration, total > 0 else { return nil }
            return (1 - displayedTime(at: date) / total).clamped(to: 0...1)
        case .stopwatchRunning, .stopwatchPaused:
            return nil
        }
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .running, .stopwatchRunning: pause()
        case .paused, .stopwatchPaused: resume()
        }
    }

    func start() {
        state = usesStopwatch ? .stopwatchRunning(start: .now) : .running(end: .now.addingTimeInterval(phaseDuration))
        sessionDuration = usesStopwatch ? nil : phaseDuration
        changed()
    }

    /// Starts a focus session of `minutes` for a to-do.
    func startFocus(minutes: Int, taskID: UUID, title: String) {
        phase = .focus
        usesStopwatch = false
        self.taskID = taskID
        taskTitle = title
        let duration = TimeInterval(minutes * 60)
        sessionDuration = duration
        state = .running(end: .now.addingTimeInterval(duration))
        changed()
    }

    func pause() {
        switch state {
        case let .running(end): state = .paused(remaining: max(end.timeIntervalSinceNow, 0))
        case let .stopwatchRunning(start): state = .stopwatchPaused(elapsed: Date.now.timeIntervalSince(start))
        case .idle, .paused, .stopwatchPaused: return
        }
        changed()
    }

    func resume() {
        switch state {
        case let .paused(remaining): state = .running(end: .now.addingTimeInterval(remaining))
        case let .stopwatchPaused(elapsed): state = .stopwatchRunning(start: .now.addingTimeInterval(-elapsed))
        case .idle, .running, .stopwatchRunning: return
        }
        changed()
    }

    func reset() {
        state = .idle
        taskID = nil
        taskTitle = nil
        sessionDuration = nil
        changed()
    }

    /// Switches between focus and break; only while idle, so a running session is never cut short by accident.
    func select(_ phase: Phase) {
        guard state == .idle, self.phase != phase else { return }
        self.phase = phase
        changed()
    }

    func setUsesStopwatch(_ usesStopwatch: Bool) {
        guard state == .idle else { return }
        self.usesStopwatch = usesStopwatch
        changed()
    }

    // MARK: - Private

    /// Length of the session in progress; it can differ from the settings when started from a task.
    @ObservationIgnored private var sessionDuration: TimeInterval?

    private var phaseDuration: TimeInterval {
        TimeInterval(settings.minutes(for: phase) * 60)
    }

    private func changed() {
        scheduleCompletion()
        save()
    }

    private func scheduleCompletion() {
        completion?.cancel()
        guard case let .running(end) = state else { return }
        completion = Task { [weak self] in
            do {
                // Task.sleep uses the continuous clock, which keeps counting while the Mac sleeps.
                try await Task.sleep(for: .seconds(max(end.timeIntervalSinceNow, 0)))
            } catch {
                // Paused, reset or rescheduled; the new state owns the completion.
                return
            }
            self?.finishPhase(playsChime: true)
        }
    }

    /// Focus ends into an automatic break; a break ends idle, waiting for the user to start the next focus.
    private func finishPhase(playsChime: Bool) {
        if playsChime && settings.playsChime && !settings.playChime() {
            lastError = "The chime sound “\(settings.chimeSound)” is not available."
        }
        switch phase {
        case .focus:
            phase = .rest
            taskID = nil
            taskTitle = nil
            sessionDuration = phaseDuration
            state = playsChime ? .running(end: .now.addingTimeInterval(phaseDuration)) : .idle
        case .rest:
            phase = .focus
            sessionDuration = nil
            state = .idle
        }
        changed()
    }

    private func save() {
        let snapshot = Snapshot(
            phase: phase,
            state: state,
            usesStopwatch: usesStopwatch,
            taskID: taskID,
            taskTitle: taskTitle,
            sessionDuration: sessionDuration
        )
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.defaultsKey)
        } catch {
            lastError = "The timer state could not be saved: \(error.localizedDescription)"
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return }
        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            phase = snapshot.phase
            state = snapshot.state
            usesStopwatch = snapshot.usesStopwatch
            taskID = snapshot.taskID
            taskTitle = snapshot.taskTitle
            sessionDuration = snapshot.sessionDuration
        } catch {
            lastError = "The saved timer state could not be read; the timer was reset."
            return
        }
        switch state {
        case let .running(end) where end <= .now:
            // The phase ended while the app was closed: move on silently instead of starting a late break.
            finishPhase(playsChime: false)
        case .running:
            scheduleCompletion()
        default:
            break
        }
    }
}
