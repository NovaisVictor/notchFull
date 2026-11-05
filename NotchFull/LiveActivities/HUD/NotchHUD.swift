import Foundation
import Observation
import os

/// Turns volume and brightness key presses into changes and shows the result in the notch.
@MainActor
@Observable
final class NotchHUD {
    /// What went wrong for one kind of key, shown in its settings section.
    struct Issues: Equatable {
        /// The last change failed; the key went to macOS.
        var error: String?
        /// Why the last key went to macOS instead of the notch, such as an output with fixed volume.
        var passThroughReason: String?
    }

    /// Long enough to read the value; each press shows the HUD again, so it stays while a key repeats.
    static let duration: Duration = .seconds(1.5)
    /// macOS moves volume and brightness in sixteenths, or in quarters of that with Option and Shift.
    static let steps = 16
    static let fineSteps = 64

    let keyTap = MediaKeyTap()
    let brightness = BrightnessController()
    private(set) var volumeIssues = Issues()
    private(set) var brightnessIssues = Issues()

    private let settings: HUDSettings
    private let liveActivities: LiveActivityCenter
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "hud")

    init(settings: HUDSettings, liveActivities: LiveActivityCenter) {
        self.settings = settings
        self.liveActivities = liveActivities
        keyTap.onKeyDown = { [weak self] press in
            guard let self else { return false }
            return handle(press)
        }
    }

    func setIntercepting(_ intercepts: Bool) {
        if intercepts {
            keyTap.start()
        } else {
            keyTap.stop()
        }
    }

    func show(_ state: HUDState) {
        liveActivities.present(.hud(state, style: settings.style), for: Self.duration)
    }

    private func handle(_ press: MediaKeyPress) -> Bool {
        let steps = press.isFine ? Self.fineSteps : Self.steps
        // The tap runs while either option is on, so each key checks its own option before being consumed.
        switch press.key {
        case .volumeUp: return settings.replacesVolume && applyVolume(.step(up: true, steps: steps))
        case .volumeDown: return settings.replacesVolume && applyVolume(.step(up: false, steps: steps))
        case .mute: return settings.replacesVolume && applyVolume(.toggleMute)
        case .brightnessUp: return settings.replacesBrightness && applyBrightness(up: true, steps: steps)
        case .brightnessDown: return settings.replacesBrightness && applyBrightness(up: false, steps: steps)
        }
    }

    private func applyVolume(_ change: VolumeController.Change) -> Bool {
        let outcome: VolumeController.Outcome
        do {
            outcome = try VolumeController.apply(change)
        } catch {
            // The key still reaches macOS, so a Core Audio failure never leaves the user without volume control.
            update(\.volumeIssues) { $0.error = error.localizedDescription }
            Self.log.error("Volume change failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        switch outcome {
        case let .applied(state):
            update(\.volumeIssues) { $0 = Issues() }
            show(state)
            return true
        case let .unsupported(reason):
            update(\.volumeIssues) { $0.passThroughReason = reason }
            Self.log.notice("Volume key passed to macOS: \(reason, privacy: .public)")
            return false
        }
    }

    private func applyBrightness(up: Bool, steps: Int) -> Bool {
        let outcome: BrightnessController.Outcome
        do {
            outcome = try brightness.step(up: up, steps: steps)
        } catch {
            // The key still reaches macOS, so a DisplayServices failure never leaves the user without brightness control.
            update(\.brightnessIssues) { $0.error = error.localizedDescription }
            Self.log.error("Brightness change failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        switch outcome {
        case let .applied(state):
            update(\.brightnessIssues) { $0 = Issues() }
            show(state)
            return true
        case let .unsupported(reason):
            update(\.brightnessIssues) { $0.passThroughReason = reason }
            Self.log.notice("Brightness key passed to macOS: \(reason, privacy: .public)")
            return false
        }
    }

    /// Writes only real changes, so a repeating key does not invalidate the settings page on every press.
    private func update(_ keyPath: ReferenceWritableKeyPath<NotchHUD, Issues>, _ change: (inout Issues) -> Void) {
        var issues = self[keyPath: keyPath]
        change(&issues)
        if self[keyPath: keyPath] != issues {
            self[keyPath: keyPath] = issues
        }
    }
}
