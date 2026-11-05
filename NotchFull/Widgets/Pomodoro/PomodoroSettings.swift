import AppKit
import Foundation
import Observation

/// Pomodoro preferences; each change is persisted immediately.
@MainActor
@Observable
final class PomodoroSettings {
    static let focusRange = 1...120
    static let breakRange = 1...60
    /// Short system sounds suitable for a chime; they ship with macOS, so the app bundles no audio.
    static let chimeSounds = ["Glass", "Hero", "Ping", "Purr", "Submarine", "Tink", "Blow", "Bottle", "Pop"]

    private enum Key {
        static let focusMinutes = "pomodoro.focusMinutes"
        static let breakMinutes = "pomodoro.breakMinutes"
        static let showsInNotch = "pomodoro.showsInNotch"
        static let showsSatellite = "pomodoro.showsSatellite"
        static let chimeSound = "pomodoro.chimeSound"
        static let playsChime = "pomodoro.playsChime"
        static let rainDuringBreaks = "pomodoro.rainDuringBreaks"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: Key.breakMinutes) } }
    /// Shows the running timer as a live activity in the closed notch.
    var showsInNotch: Bool { didSet { defaults.set(showsInNotch, forKey: Key.showsInNotch) } }
    /// Shows the floating circle next to the notch while the timer runs.
    var showsSatellite: Bool { didSet { defaults.set(showsSatellite, forKey: Key.showsSatellite) } }
    var chimeSound: String { didSet { defaults.set(chimeSound, forKey: Key.chimeSound) } }
    var playsChime: Bool { didSet { defaults.set(playsChime, forKey: Key.playsChime) } }
    var rainDuringBreaks: Bool { didSet { defaults.set(rainDuringBreaks, forKey: Key.rainDuringBreaks) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        focusMinutes = defaults.value(forKey: Key.focusMinutes, default: 25).clamped(to: Self.focusRange)
        breakMinutes = defaults.value(forKey: Key.breakMinutes, default: 5).clamped(to: Self.breakRange)
        showsInNotch = defaults.value(forKey: Key.showsInNotch, default: true)
        showsSatellite = defaults.value(forKey: Key.showsSatellite, default: true)
        let sound = defaults.value(forKey: Key.chimeSound, default: "Glass")
        chimeSound = Self.chimeSounds.contains(sound) ? sound : "Glass"
        playsChime = defaults.value(forKey: Key.playsChime, default: true)
        rainDuringBreaks = defaults.value(forKey: Key.rainDuringBreaks, default: false)
    }

    func minutes(for phase: PomodoroTimer.Phase) -> Int {
        phase == .focus ? focusMinutes : breakMinutes
    }

    func setMinutes(_ minutes: Int, for phase: PomodoroTimer.Phase) {
        switch phase {
        case .focus: focusMinutes = minutes.clamped(to: Self.focusRange)
        case .rest: breakMinutes = minutes.clamped(to: Self.breakRange)
        }
    }

    /// Plays `sound` (the configured chime by default); `false` when macOS has no sound by that name.
    @discardableResult
    func playChime(_ sound: String? = nil) -> Bool {
        guard let chime = NSSound(named: sound ?? chimeSound) else { return false }
        chime.stop()
        return chime.play()
    }
}
