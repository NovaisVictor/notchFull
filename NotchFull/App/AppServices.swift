import Observation

/// Data sources and settings shared by every screen's notch, so each is created and observed once.
@MainActor
final class AppServices {
    let layout = WidgetLayoutStore()
    let appearance = AppearanceSettings()
    let interaction = NotchInteraction()
    let screens = ScreenSettings()
    let behavior = BehaviorSettings()
    let fullscreen = FullscreenMonitor()
    let calendar = CalendarStore()
    let todoSettings = TodoSettings()
    let todos: TodoStore
    let pomodoroSettings = PomodoroSettings()
    let pomodoro: PomodoroTimer
    let rain = RainAmbience()
    let satellites: SatelliteCenter
    let nowPlaying = NowPlayingStore()
    let mediaSettings = MediaActivitySettings()
    let activitySettings = ActivitySettings()
    let spectrum = AudioSpectrumSource()
    let battery = BatteryMonitor()
    let bluetooth = BluetoothMonitor()
    let downloads = DownloadsMonitor()
    let liveActivities: LiveActivityCenter
    private var upcomingEvents: UpcomingEventNotifier?

    init() {
        todos = TodoStore(settings: todoSettings)
        pomodoro = PomodoroTimer(settings: pomodoroSettings)
        satellites = SatelliteCenter(timer: pomodoro, settings: pomodoroSettings)
        liveActivities = LiveActivityCenter(
            nowPlaying: nowPlaying,
            mediaSettings: mediaSettings,
            downloads: downloads,
            activitySettings: activitySettings,
            pomodoro: pomodoro,
            pomodoroSettings: pomodoroSettings
        )
        routeEventsToLiveActivities()
        observeAudioDemand()
        observeRainDemand()
    }

    /// Rain plays only during a running break, when the user turned it on.
    private func observeRainDemand() {
        let shouldPlay = withObservationTracking {
            pomodoroSettings.rainDuringBreaks && pomodoro.phase == .rest && pomodoro.isRunning
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeRainDemand() }
        }
        rain.setPlaying(shouldPlay)
    }

    /// Each event source reports raw changes; the user's activity settings decide what reaches the notch.
    private func routeEventsToLiveActivities() {
        battery.onChange = { [weak self] previous, current in
            guard let self,
                  let event = BatteryMonitor.Event.detect(from: previous, to: current, lowThreshold: activitySettings.lowBatteryThreshold),
                  activitySettings.shows(event) else { return }
            liveActivities.present(.power(event, current))
        }
        bluetooth.onEvent = { [weak self] device in
            guard let self, activitySettings.showsBluetooth else { return }
            liveActivities.present(.bluetooth(device))
        }
        downloads.onFinished = { [weak self] fileName in
            guard let self, activitySettings.showsDownloads else { return }
            liveActivities.present(.downloadFinished(fileName: fileName))
        }
        upcomingEvents = UpcomingEventNotifier(calendar: calendar, settings: activitySettings) { [weak self] event in
            self?.liveActivities.present(.upcomingEvent(event), for: .seconds(6))
        }
    }

    /// Captures the player's audio only while an audio-reactive effect is visible and music is playing.
    private func observeAudioDemand() {
        let player = withObservationTracking {
            let wantsCapture = mediaSettings.isEnabled
                && mediaSettings.usesSystemAudio
                && mediaSettings.effect.isAudioReactive
                && nowPlaying.nowPlaying?.isPlaying == true
            return wantsCapture ? nowPlaying.activePlayer : nil
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeAudioDemand() }
        }
        // Applied outside the tracking scope so capture status changes do not re-trigger this observation.
        spectrum.capture(player)
    }
}

/// Interaction state that must keep the notch open even when the pointer leaves it.
@MainActor
@Observable
final class NotchInteraction {
    /// A text field inside the notch has keyboard focus.
    var isEditingText = false
}
