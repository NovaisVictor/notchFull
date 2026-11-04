import Foundation
import Observation

enum NotchStyle: String, CaseIterable, Identifiable {
    /// Solid black, like the camera housing.
    case classic
    /// Dark Liquid Glass: almost black, with the wallpaper glowing faintly through the edges.
    case smokedGlass
    /// Light, frosted Liquid Glass.
    case glass
    /// Liquid Glass with more of the wallpaper showing through.
    case clearGlass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .smokedGlass: "Smoked glass"
        case .glass: "Frosted glass"
        case .clearGlass: "Clear glass"
        }
    }

    var summary: String {
        switch self {
        case .classic: "Solid black, like the camera housing."
        case .smokedGlass: "Dark glass; your wallpaper glows through the edges."
        case .glass: "A bright, frosted surface."
        case .clearGlass: "More wallpaper, less frost."
        }
    }

    var usesGlass: Bool { self != .classic }
}

enum MusicWidgetLayout: String, CaseIterable, Identifiable {
    case standard
    case expanded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .expanded: "Expanded"
        }
    }

    var summary: String {
        switch self {
        case .standard: "Track and controls"
        case .expanded: "Adds the app and the track progress"
        }
    }
}

/// Look of the open notch and its widgets; each change is persisted immediately.
@MainActor
@Observable
final class AppearanceSettings {
    private enum Key {
        static let notchStyle = "appearance.notchStyle"
        static let musicLayout = "appearance.musicLayout"
        static let glassLevel = "appearance.glassLevel"
    }

    static let glassLevelRange = 0.3...0.95
    static let defaultGlassLevel = 0.7

    @ObservationIgnored private let defaults: UserDefaults

    var notchStyle: NotchStyle { didSet { defaults.set(notchStyle.rawValue, forKey: Key.notchStyle) } }
    var musicLayout: MusicWidgetLayout { didSet { defaults.set(musicLayout.rawValue, forKey: Key.musicLayout) } }
    /// How dark smoked glass is: higher hides more of the wallpaper.
    var glassLevel: Double { didSet { defaults.set(glassLevel, forKey: Key.glassLevel) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notchStyle = defaults.rawValue(forKey: Key.notchStyle, default: .classic)
        musicLayout = defaults.rawValue(forKey: Key.musicLayout, default: .expanded)
        glassLevel = defaults.value(forKey: Key.glassLevel, default: Self.defaultGlassLevel).clamped(to: Self.glassLevelRange)
    }
}
