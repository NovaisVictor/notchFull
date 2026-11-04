import Foundation
import Observation

enum MediaEffect: String, CaseIterable, Identifiable {
    case spectrograph
    case wave
    case vibratingCircle
    case gif
    case off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spectrograph: "Audio Spectrograph"
        case .wave: "Waves"
        case .vibratingCircle: "Vibrating Circle"
        case .gif: "GIF"
        case .off: "None"
        }
    }

    var isAudioReactive: Bool {
        switch self {
        case .spectrograph, .wave, .vibratingCircle: true
        case .gif, .off: false
        }
    }
}

/// Preferences for the music live activity; each change is persisted immediately.
@MainActor
@Observable
final class MediaActivitySettings {
    static let barCountRange = 3...10
    static let gifScaleRange = 0.5...2.0
    static let artworkCornerRadiusRange = 0.0...12.0

    private enum Key {
        static let isEnabled = "media.isEnabled"
        static let effect = "media.effect"
        static let barCount = "media.barCount"
        static let usesSystemAudio = "media.usesSystemAudio"
        static let tintsWithArtwork = "media.tintsWithArtwork"
        static let artworkCornerRadius = "media.artworkCornerRadius"
        static let gifPath = "media.gifPath"
        static let gifScale = "media.gifScale"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.isEnabled) } }
    var effect: MediaEffect { didSet { defaults.set(effect.rawValue, forKey: Key.effect) } }
    var barCount: Int { didSet { defaults.set(barCount, forKey: Key.barCount) } }
    /// Drives the effect from the player's real audio; requires the System Audio Recording permission.
    var usesSystemAudio: Bool { didSet { defaults.set(usesSystemAudio, forKey: Key.usesSystemAudio) } }
    var tintsWithArtwork: Bool { didSet { defaults.set(tintsWithArtwork, forKey: Key.tintsWithArtwork) } }
    var artworkCornerRadius: Double { didSet { defaults.set(artworkCornerRadius, forKey: Key.artworkCornerRadius) } }
    var gifURL: URL? { didSet { defaults.set(gifURL?.path, forKey: Key.gifPath) } }
    var gifScale: Double { didSet { defaults.set(gifScale, forKey: Key.gifScale) } }

    // Unset keys fall back to the defaults below; stored values outside the valid range are clamped.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.value(forKey: Key.isEnabled, default: true)
        effect = defaults.rawValue(forKey: Key.effect, default: .spectrograph)
        barCount = defaults.value(forKey: Key.barCount, default: 4).clamped(to: Self.barCountRange)
        usesSystemAudio = defaults.value(forKey: Key.usesSystemAudio, default: false)
        tintsWithArtwork = defaults.value(forKey: Key.tintsWithArtwork, default: true)
        artworkCornerRadius = defaults.value(forKey: Key.artworkCornerRadius, default: 6.0).clamped(to: Self.artworkCornerRadiusRange)
        gifURL = defaults.string(forKey: Key.gifPath).map { URL(fileURLWithPath: $0) }
        gifScale = defaults.value(forKey: Key.gifScale, default: 1.0).clamped(to: Self.gifScaleRange)
    }
}
