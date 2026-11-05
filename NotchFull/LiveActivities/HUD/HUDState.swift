import Foundation

/// What the HUD shows after a volume or brightness key press.
struct HUDState: Equatable {
    enum Kind: Equatable {
        /// `deviceName` is `nil` for the built-in output (the HUD then just says "Volume").
        case volume(isMuted: Bool, deviceName: String?)
        case brightness
    }

    let kind: Kind
    /// 0...1
    let level: Double

    static func volume(level: Double, isMuted: Bool, deviceName: String?) -> HUDState {
        HUDState(kind: .volume(isMuted: isMuted, deviceName: deviceName), level: level)
    }

    static func brightness(level: Double) -> HUDState {
        HUDState(kind: .brightness, level: level)
    }

    var title: String {
        switch kind {
        case let .volume(_, deviceName): deviceName ?? "Volume"
        case .brightness: "Brightness"
        }
    }

    /// Drawn faded: a muted output.
    var isDimmed: Bool {
        if case .volume(isMuted: true, _) = kind { return true }
        return false
    }

    /// Level as the HUD reads it: a muted output shows 0.
    var shownLevel: Double { isDimmed ? 0 : level }

    /// Speaker with 0–3 waves by level (slashed when muted), or a small or large sun, like the system HUD.
    var systemImage: String {
        switch kind {
        case .volume(isMuted: true, _):
            return "speaker.slash.fill"
        case .volume:
            switch level {
            case ...0: return "speaker.fill"
            case ..<(1.0 / 3): return "speaker.wave.1.fill"
            case ..<(2.0 / 3): return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        case .brightness:
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}
