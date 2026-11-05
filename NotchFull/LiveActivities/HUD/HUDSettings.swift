import Foundation
import Observation

/// How the volume and brightness HUD appears in the notch.
enum HUDStyle: String, CaseIterable, Identifiable {
    /// Stays in the notch line: icon and title on the left, mini bar and number on the right.
    case embedded
    /// The notch grows below with an icon, a horizontal bar and the percentage.
    case classic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .embedded: "Embedded"
        case .classic: "Classic"
        }
    }
}

/// Volume and brightness HUD preferences; each change is persisted immediately.
@MainActor
@Observable
final class HUDSettings {
    private enum Key {
        static let replacesVolume = "hud.replacesVolume"
        static let replacesBrightness = "hud.replacesBrightness"
        static let style = "hud.style"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Intercepts the volume keys and shows the notch HUD instead of the system one; needs Accessibility.
    var replacesVolume: Bool { didSet { defaults.set(replacesVolume, forKey: Key.replacesVolume) } }
    /// Intercepts the brightness keys for the built-in display; needs Accessibility and DisplayServices.
    var replacesBrightness: Bool { didSet { defaults.set(replacesBrightness, forKey: Key.replacesBrightness) } }
    var style: HUDStyle { didSet { defaults.set(style.rawValue, forKey: Key.style) } }

    /// Whether any key needs the media key tap.
    var replacesAnyKey: Bool { replacesVolume || replacesBrightness }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        replacesVolume = defaults.value(forKey: Key.replacesVolume, default: false)
        replacesBrightness = defaults.value(forKey: Key.replacesBrightness, default: false)
        style = defaults.rawValue(forKey: Key.style, default: .embedded)
    }
}
