import AppKit
import Foundation
import Observation

/// How the notch opens, reacts to typing, gives haptic feedback and responds to trackpad gestures.
/// Each change is persisted immediately.
@MainActor
@Observable
final class BehaviorSettings {
    private enum Key {
        static let opensOnHover = "behavior.opensOnHover"
        static let haptics = "behavior.haptics"
        static let keepsOpenWhileTyping = "behavior.keepsOpenWhileTyping"
        static let gesturesEnabled = "behavior.gesturesEnabled"
        static let verticalGestures = "behavior.verticalGestures"
        static let horizontalMediaGestures = "behavior.horizontalMediaGestures"
        static let invertsMediaGestures = "behavior.invertsMediaGestures"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Off: hovering only highlights the notch and a click opens it.
    var opensOnHover: Bool { didSet { defaults.set(opensOnHover, forKey: Key.opensOnHover) } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: Key.haptics) } }
    var keepsOpenWhileTyping: Bool { didSet { defaults.set(keepsOpenWhileTyping, forKey: Key.keepsOpenWhileTyping) } }
    var gesturesEnabled: Bool { didSet { defaults.set(gesturesEnabled, forKey: Key.gesturesEnabled) } }
    var verticalGestures: Bool { didSet { defaults.set(verticalGestures, forKey: Key.verticalGestures) } }
    var horizontalMediaGestures: Bool { didSet { defaults.set(horizontalMediaGestures, forKey: Key.horizontalMediaGestures) } }
    var invertsMediaGestures: Bool { didSet { defaults.set(invertsMediaGestures, forKey: Key.invertsMediaGestures) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        opensOnHover = defaults.value(forKey: Key.opensOnHover, default: true)
        haptics = defaults.value(forKey: Key.haptics, default: true)
        keepsOpenWhileTyping = defaults.value(forKey: Key.keepsOpenWhileTyping, default: true)
        gesturesEnabled = defaults.value(forKey: Key.gesturesEnabled, default: true)
        verticalGestures = defaults.value(forKey: Key.verticalGestures, default: true)
        horizontalMediaGestures = defaults.value(forKey: Key.horizontalMediaGestures, default: true)
        invertsMediaGestures = defaults.value(forKey: Key.invertsMediaGestures, default: false)
    }

    /// A short tap on Force Touch trackpads; other pointing devices ignore it.
    func playHaptic() {
        guard haptics else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
