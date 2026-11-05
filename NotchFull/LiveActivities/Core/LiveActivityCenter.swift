import CoreGraphics
import Observation

/// Decides which live activity the closed notch shows, in priority order:
/// a short-lived event (charger, Bluetooth, reminder, volume or brightness HUD), then an ongoing download, the Pomodoro, then music.
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
        case hud(HUDState, style: HUDStyle)

        /// Width added on each side of the notch while this activity is shown.
        func sideWidth(closedHeight: CGFloat) -> CGFloat {
            let base = LiveActivityCenter.sideWidth(closedHeight: closedHeight)
            switch self {
            case .hud(_, .embedded): return base + HUDMetrics.embeddedExtraWidth
            default: return base
            }
        }

        /// Height of the content this activity draws below the closed notch, outside any peek.
        var heightBelowNotch: CGFloat {
            switch self {
            case .hud(_, .classic): HUDMetrics.classicHeight
            default: 0
            }
        }
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
    nonisolated static func sideWidth(closedHeight: CGFloat) -> CGFloat {
        closedHeight + 14
    }
}
