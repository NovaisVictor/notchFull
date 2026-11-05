import Foundation
import Observation

/// Notes widget preferences; each change is persisted immediately.
@MainActor
@Observable
final class NotesSettings {
    private enum Key {
        static let showsScrollIndicator = "notes.showsScrollIndicator"
        static let codeMode = "notes.codeMode"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showsScrollIndicator: Bool { didSet { defaults.set(showsScrollIndicator, forKey: Key.showsScrollIndicator) } }
    /// Every note shows as monospaced plain text with syntax highlighting; notes edited in this mode are saved as plain text.
    var codeMode: Bool { didSet { defaults.set(codeMode, forKey: Key.codeMode) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsScrollIndicator = defaults.value(forKey: Key.showsScrollIndicator, default: false)
        codeMode = defaults.value(forKey: Key.codeMode, default: false)
    }
}
