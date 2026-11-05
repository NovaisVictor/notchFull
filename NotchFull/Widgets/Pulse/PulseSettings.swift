import Foundation
import Observation

enum PulseStyle: String, CaseIterable, Identifiable {
    case rings
    case graphs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rings: "Rings"
        case .graphs: "Graphs"
        }
    }

    var summary: String {
        switch self {
        case .rings: "A colored ring per metric"
        case .graphs: "The value and its recent history"
        }
    }
}

/// Pulse widget preferences; each change is persisted immediately.
@MainActor
@Observable
final class PulseSettings {
    static let intervalOptions = [1, 2, 5]

    private enum Key {
        static let style = "pulse.style"
        static let metrics = "pulse.metrics"
        static let explainsOnHover = "pulse.explainsOnHover"
        static let interval = "pulse.interval"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var style: PulseStyle { didSet { defaults.set(style.rawValue, forKey: Key.style) } }
    var enabledMetrics: Set<PulseMetric> {
        didSet { defaults.set(enabledMetrics.map(\.rawValue).sorted(), forKey: Key.metrics) }
    }
    /// Hovering a metric shows a sentence with its detail, such as "RAM: 12.4 of 16 GB".
    var explainsOnHover: Bool { didSet { defaults.set(explainsOnHover, forKey: Key.explainsOnHover) } }
    /// Seconds between samples; one of `intervalOptions`.
    var interval: Int { didSet { defaults.set(interval, forKey: Key.interval) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        style = defaults.rawValue(forKey: Key.style, default: .rings)
        let storedMetrics: [String] = defaults.value(forKey: Key.metrics, default: PulseMetric.allCases.map(\.rawValue))
        enabledMetrics = Set(storedMetrics.compactMap(PulseMetric.init(rawValue:)))
        explainsOnHover = defaults.value(forKey: Key.explainsOnHover, default: true)
        let storedInterval = defaults.value(forKey: Key.interval, default: 2)
        interval = Self.intervalOptions.contains(storedInterval) ? storedInterval : 2
    }

    /// Enabled metrics in their fixed display order.
    var visibleMetrics: [PulseMetric] {
        PulseMetric.allCases.filter(enabledMetrics.contains)
    }

    func isEnabled(_ metric: PulseMetric) -> Bool {
        enabledMetrics.contains(metric)
    }

    func setEnabled(_ metric: PulseMetric, _ isEnabled: Bool) {
        if isEnabled {
            enabledMetrics.insert(metric)
        } else {
            enabledMetrics.remove(metric)
        }
    }
}
