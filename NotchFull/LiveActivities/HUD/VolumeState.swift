import Foundation

/// What the volume HUD shows after a key press.
struct VolumeState: Equatable {
    /// 0...1
    let level: Double
    let isMuted: Bool
    /// Name of the output device, or `nil` for the built-in output (the HUD then just says "Volume").
    let deviceName: String?

    var title: String { deviceName ?? "Volume" }

    /// Level as the HUD reads it: a muted output shows 0.
    var shownLevel: Double { isMuted ? 0 : level }

    /// Speaker with 0–3 waves by level, slashed when muted, like the system HUD.
    var systemImage: String {
        if isMuted { return "speaker.slash.fill" }
        switch level {
        case ...0: return "speaker.fill"
        case ..<(1.0 / 3): return "speaker.wave.1.fill"
        case ..<(2.0 / 3): return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}
