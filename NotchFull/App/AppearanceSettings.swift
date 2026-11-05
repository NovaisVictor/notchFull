import Foundation
import Observation
import SwiftUI

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

/// Look of the notch: material, sizes and how it animates. Each change is persisted immediately.
@MainActor
@Observable
final class AppearanceSettings {
    private enum Key {
        static let notchStyle = "appearance.notchStyle"
        static let musicLayout = "appearance.musicLayout"
        static let glassLevel = "appearance.glassLevel"
        static let cellWidth = "appearance.cellWidth"
        static let cardHeight = "appearance.cardHeight"
        static let notchWidthAdjustment = "appearance.notchWidthAdjustment"
        static let notchHeightAdjustment = "appearance.notchHeightAdjustment"
        static let animationDuration = "appearance.animationDuration"
        static let animationBounces = "appearance.animationBounces"
    }

    static let glassLevelRange = 0.3...0.95
    static let defaultGlassLevel = 0.7
    /// Island width: the width of one widget cell, so every widget scales together.
    static let cellWidthRange = 48.0...72.0
    static let defaultCellWidth = 58.0
    /// Island height: the height of the widget row.
    nonisolated static let cardHeightRange = 110.0...170.0
    static let defaultCardHeight = 132.0
    /// Corrections added to the measured physical notch, for when the drawn notch does not line up with the camera housing.
    static let notchWidthAdjustmentRange = -40.0...40.0
    static let notchHeightAdjustmentRange = -8.0...8.0
    static let animationDurationRange = 0.2...0.9
    static let defaultAnimationDuration = 0.5

    @ObservationIgnored private let defaults: UserDefaults

    var notchStyle: NotchStyle { didSet { defaults.set(notchStyle.rawValue, forKey: Key.notchStyle) } }
    var musicLayout: MusicWidgetLayout { didSet { defaults.set(musicLayout.rawValue, forKey: Key.musicLayout) } }
    /// How dark smoked glass is: higher hides more of the wallpaper.
    var glassLevel: Double { didSet { defaults.set(glassLevel, forKey: Key.glassLevel) } }
    var cellWidth: Double { didSet { defaults.set(cellWidth, forKey: Key.cellWidth) } }
    var cardHeight: Double { didSet { defaults.set(cardHeight, forKey: Key.cardHeight) } }
    var notchWidthAdjustment: Double { didSet { defaults.set(notchWidthAdjustment, forKey: Key.notchWidthAdjustment) } }
    var notchHeightAdjustment: Double { didSet { defaults.set(notchHeightAdjustment, forKey: Key.notchHeightAdjustment) } }
    /// Seconds the notch takes to open or close.
    var animationDuration: Double { didSet { defaults.set(animationDuration, forKey: Key.animationDuration) } }
    var animationBounces: Bool { didSet { defaults.set(animationBounces, forKey: Key.animationBounces) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notchStyle = defaults.rawValue(forKey: Key.notchStyle, default: .classic)
        musicLayout = defaults.rawValue(forKey: Key.musicLayout, default: .expanded)
        glassLevel = defaults.value(forKey: Key.glassLevel, default: Self.defaultGlassLevel).clamped(to: Self.glassLevelRange)
        cellWidth = defaults.value(forKey: Key.cellWidth, default: Self.defaultCellWidth).clamped(to: Self.cellWidthRange)
        cardHeight = defaults.value(forKey: Key.cardHeight, default: Self.defaultCardHeight).clamped(to: Self.cardHeightRange)
        notchWidthAdjustment = defaults.value(forKey: Key.notchWidthAdjustment, default: 0.0).clamped(to: Self.notchWidthAdjustmentRange)
        notchHeightAdjustment = defaults.value(forKey: Key.notchHeightAdjustment, default: 0.0).clamped(to: Self.notchHeightAdjustmentRange)
        animationDuration = defaults.value(forKey: Key.animationDuration, default: Self.defaultAnimationDuration)
            .clamped(to: Self.animationDurationRange)
        animationBounces = defaults.value(forKey: Key.animationBounces, default: false)
    }

    var gridMetrics: WidgetGridMetrics {
        WidgetGridMetrics(cellWidth: cellWidth, cardHeight: cardHeight)
    }

    /// The spring for opening, closing and resizing the notch. No bounce by default: overshooting reads as a glitch
    /// on an element anchored to the top of the screen.
    var notchAnimation: Animation {
        .spring(duration: animationDuration, bounce: animationBounces ? 0.22 : 0)
    }

    /// Shorter animations for small changes inside the closed notch (hover, peek).
    var detailAnimation: Animation {
        .spring(duration: animationDuration * 0.7, bounce: animationBounces ? 0.18 : 0)
    }
}
