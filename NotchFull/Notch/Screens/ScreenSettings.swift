import Foundation
import Observation

enum FullscreenPolicy: String, CaseIterable, Identifiable {
    /// Keep showing over full-screen apps on every screen.
    case allScreens
    /// Over full-screen apps, keep showing only where a physical notch hides no content.
    case notchScreens
    /// Hide on any screen where an app is full screen.
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allScreens: "All screens"
        case .notchScreens: "Screens with a notch"
        case .never: "Never"
        }
    }

    var summary: String {
        switch self {
        case .allScreens: "Show over full-screen apps on every connected screen."
        case .notchScreens: "Over full-screen apps, show only on screens with a physical notch."
        case .never: "Hide while an app is full screen."
        }
    }

    var systemImage: String {
        switch self {
        case .allScreens: "rectangle.on.rectangle"
        case .notchScreens: "laptopcomputer"
        case .never: "eye.slash"
        }
    }
}

/// Which screens show the notch and how it behaves on screens without one; each change is persisted immediately.
@MainActor
@Observable
final class ScreenSettings {
    static let handleWidthRange = 80.0...300.0
    static let handleHeightRange = 4.0...16.0

    private enum Key {
        static let enabledDisplayUUIDs = "screens.enabledDisplayUUIDs"
        static let fullscreenPolicy = "screens.fullscreenPolicy"
        static let showsHandle = "screens.showsHandle"
        static let handleWidth = "screens.handleWidth"
        static let handleHeight = "screens.handleHeight"
        static let handleIsTransparent = "screens.handleIsTransparent"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Displays the user turned on, by stable UUID; `nil` means every display, including ones connected later.
    var enabledDisplayUUIDs: [String]? { didSet { defaults.set(enabledDisplayUUIDs, forKey: Key.enabledDisplayUUIDs) } }
    var fullscreenPolicy: FullscreenPolicy { didSet { defaults.set(fullscreenPolicy.rawValue, forKey: Key.fullscreenPolicy) } }
    /// Draws a small bar where the notch would be on screens without one; off leaves only the hover area.
    var showsHandle: Bool { didSet { defaults.set(showsHandle, forKey: Key.showsHandle) } }
    var handleWidth: Double { didSet { defaults.set(handleWidth, forKey: Key.handleWidth) } }
    var handleHeight: Double { didSet { defaults.set(handleHeight, forKey: Key.handleHeight) } }
    var handleIsTransparent: Bool { didSet { defaults.set(handleIsTransparent, forKey: Key.handleIsTransparent) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabledDisplayUUIDs = defaults.stringArray(forKey: Key.enabledDisplayUUIDs)
        fullscreenPolicy = defaults.rawValue(forKey: Key.fullscreenPolicy, default: .notchScreens)
        showsHandle = defaults.value(forKey: Key.showsHandle, default: true)
        handleWidth = defaults.value(forKey: Key.handleWidth, default: 184.0).clamped(to: Self.handleWidthRange)
        handleHeight = defaults.value(forKey: Key.handleHeight, default: 8.0).clamped(to: Self.handleHeightRange)
        handleIsTransparent = defaults.value(forKey: Key.handleIsTransparent, default: false)
    }

    func isEnabled(_ uuid: String) -> Bool {
        enabledDisplayUUIDs.map { $0.contains(uuid) } ?? true
    }

    /// Turns one display on or off; `connected` lists every display now attached, needed to leave the "all" state.
    func setEnabled(_ isEnabled: Bool, uuid: String, connected: [String]) {
        var enabled = Set(enabledDisplayUUIDs ?? connected)
        if isEnabled {
            enabled.insert(uuid)
        } else {
            enabled.remove(uuid)
        }
        // Every connected display on again means "all", so displays connected later show the notch too.
        enabledDisplayUUIDs = Set(connected).isSubset(of: enabled) ? nil : enabled.sorted()
    }

    func enableAll() {
        enabledDisplayUUIDs = nil
    }

    func enableOnly(_ uuids: [String]) {
        enabledDisplayUUIDs = uuids.sorted()
    }
}
