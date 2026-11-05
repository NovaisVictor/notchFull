import CoreGraphics
import Observation

/// Decides which live activity the closed notch shows, in priority order:
/// a short-lived event (charger, Bluetooth, reminder), then an ongoing download, the Pomodoro, then music.
@MainActor
@Observable
final class LiveActivityCenter {
    enum Activity: Equatable {
        case media
        case power(BatteryMonitor.Event, BatteryMonitor.Reading)
        case bluetooth(BluetoothDevice)
        case download(DownloadsMonitor.Download)
        case downloadFinished(fileName: String)
        case upcomingEvent(UpcomingEvent)
        case pomodoro
    }

    static let eventDuration: Duration = .seconds(3.5)

    private let nowPlaying: NowPlayingStore
    private let mediaSettings: MediaActivitySettings
    private let downloads: DownloadsMonitor
    private let activitySettings: ActivitySettings
    private let pomodoro: PomodoroTimer
    private let pomodoroSettings: PomodoroSettings
    private(set) var event: Activity?
    @ObservationIgnored private var eventExpiry: Task<Void, Never>?

    init(
        nowPlaying: NowPlayingStore,
        mediaSettings: MediaActivitySettings,
        downloads: DownloadsMonitor,
        activitySettings: ActivitySettings,
        pomodoro: PomodoroTimer,
        pomodoroSettings: PomodoroSettings
    ) {
        self.nowPlaying = nowPlaying
        self.mediaSettings = mediaSettings
        self.downloads = downloads
        self.activitySettings = activitySettings
        self.pomodoro = pomodoro
        self.pomodoroSettings = pomodoroSettings
    }

    var current: Activity? {
        if let event { return event }
        if activitySettings.showsDownloads, let download = downloads.current { return .download(download) }
        if pomodoroSettings.showsInNotch, pomodoro.isActive { return .pomodoro }
        if mediaSettings.isEnabled, nowPlaying.isActive { return .media }
        return nil
    }

    /// Shows `activity` for `duration`, replacing any event still on screen.
    func present(_ activity: Activity, for duration: Duration = eventDuration) {
        event = activity
        eventExpiry?.cancel()
        eventExpiry = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                // Cancelled because a newer event replaced this one; that event owns the expiry now.
                return
            }
            self?.event = nil
        }
    }

    /// Width added on each side of the notch while an activity is shown: a square slot plus breathing room.
    static func sideWidth(closedHeight: CGFloat) -> CGFloat {
        closedHeight + 14
    }
}
