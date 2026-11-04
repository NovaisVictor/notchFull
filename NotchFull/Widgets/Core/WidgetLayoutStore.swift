import Foundation
import Observation

/// Single owner of which widgets are enabled and in what order.
@MainActor
@Observable
final class WidgetLayoutStore {
    private static let defaultsKey = "widgetLayout"

    private let defaults: UserDefaults
    private(set) var enabled: [WidgetKind]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = Self.load(from: defaults)
    }

    var disabled: [WidgetKind] {
        WidgetKind.allCases.filter { !enabled.contains($0) }
    }

    func setEnabled(_ kind: WidgetKind, _ isEnabled: Bool) {
        if isEnabled {
            guard !enabled.contains(kind) else { return }
            enabled.append(kind)
        } else {
            enabled.removeAll { $0 == kind }
        }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        enabled.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // The whole layout is written as one value, so a reader never sees a half-applied change.
    private func save() {
        defaults.set(enabled.map(\.rawValue), forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [WidgetKind] {
        guard let stored = defaults.stringArray(forKey: defaultsKey) else {
            return WidgetKind.defaultLayout
        }
        // Kinds removed from the catalog in a later version are dropped; duplicates are ignored.
        var seen = Set<WidgetKind>()
        return stored
            .compactMap(WidgetKind.init(rawValue:))
            .filter { seen.insert($0).inserted }
    }
}
