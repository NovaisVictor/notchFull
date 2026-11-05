import Foundation
import Observation

/// To-do widget preferences; each change is persisted immediately.
@MainActor
@Observable
final class TodoSettings {
    static let autoArchiveRange = 0...30
    static let focusMinuteOptions = [15, 25, 45, 60]

    private enum Key {
        static let showsCompleted = "todos.showsCompleted"
        static let autoArchiveDays = "todos.autoArchiveDays"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showsCompleted: Bool { didSet { defaults.set(showsCompleted, forKey: Key.showsCompleted) } }
    /// Completed tasks older than this many days are archived; 0 never archives.
    var autoArchiveDays: Int { didSet { defaults.set(autoArchiveDays, forKey: Key.autoArchiveDays) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsCompleted = defaults.value(forKey: Key.showsCompleted, default: true)
        autoArchiveDays = defaults.value(forKey: Key.autoArchiveDays, default: 7).clamped(to: Self.autoArchiveRange)
    }
}
