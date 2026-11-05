import Foundation
import Observation
import os

/// Turns volume key presses into Core Audio changes and shows the result in the notch.
@MainActor
@Observable
final class VolumeHUD {
    /// Long enough to read the value; each press shows the HUD again, so it stays while a key repeats.
    static let duration: Duration = .seconds(1.5)
    /// macOS moves the volume in sixteenths, or in quarters of that with Option and Shift.
    static let steps = 16
    static let fineSteps = 64

    let keyTap = MediaKeyTap()
    private(set) var lastError: String?
    /// Why the last key went to macOS instead of the notch, such as an output with fixed volume.
    private(set) var passThroughReason: String?

    private let settings: HUDSettings
    private let liveActivities: LiveActivityCenter
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "volume-hud")

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

    func show(_ state: VolumeState) {
        liveActivities.present(.volume(state, style: settings.style), for: Self.duration)
    }

    private func handle(_ press: MediaKeyPress) -> Bool {
        let change: VolumeController.Change
        switch press.key {
        case .volumeUp: change = .step(up: true, steps: press.isFine ? Self.fineSteps : Self.steps)
        case .volumeDown: change = .step(up: false, steps: press.isFine ? Self.fineSteps : Self.steps)
        case .mute: change = .toggleMute
        }

        let outcome: VolumeController.Outcome
        do {
            outcome = try VolumeController.apply(change)
        } catch {
            // The key still reaches macOS, so a Core Audio failure never leaves the user without volume control.
            lastError = error.localizedDescription
            Self.log.error("Volume change failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        switch outcome {
        case let .applied(state):
            if lastError != nil { lastError = nil }
            if passThroughReason != nil { passThroughReason = nil }
            show(state)
            return true
        case let .unsupported(reason):
            if passThroughReason != reason { passThroughReason = reason }
            Self.log.notice("Volume key passed to macOS: \(reason, privacy: .public)")
            return false
        }
    }
}
