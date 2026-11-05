import Foundation
import Observation

/// Single owner of which widgets the Nook shows, in what order and how wide.
@MainActor
@Observable
final class WidgetLayoutStore {
    private static let defaultsKey = "widgetLayout.v2"
    /// Order only, written by builds before widths existed; read once to migrate.
    private static let legacyDefaultsKey = "widgetLayout"

    /// Persisted shape: kinds stay raw strings so a removed kind does not make the whole layout unreadable.
    private struct StoredPlacement: Codable {
        let kind: String
        let span: Int
    }

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var placements: [WidgetPlacement]
    private(set) var lastError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        placements = []
        placements = load()
    }

    var enabled: [WidgetKind] {
        placements.map(\.kind)
    }

    var disabled: [WidgetKind] {
        WidgetKind.allCases.filter { !enabled.contains($0) }
    }

    var totalCells: Int {
        placements.reduce(0) { $0 + $1.span }
    }

    func span(for kind: WidgetKind) -> Int {
        placements.first { $0.kind == kind }?.span ?? kind.defaultSpan
    }

    func setEnabled(_ kind: WidgetKind, _ isEnabled: Bool) {
        if isEnabled {
            guard !enabled.contains(kind) else { return }
            placements.append(WidgetPlacement(kind: kind, span: kind.defaultSpan))
        } else {
            placements.removeAll { $0.kind == kind }
        }
        save()
    }

    func setSpan(_ span: Int, for kind: WidgetKind) {
        guard let index = placements.firstIndex(where: { $0.kind == kind }) else { return }
        let clamped = span.clamped(to: kind.spanRange)
        guard placements[index].span != clamped else { return }
        placements[index].span = clamped
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        placements.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Moves `kind` to where `target` is: after it when moving right, before it when moving left,
    /// so dropping on the first or last widget reaches both ends.
    func move(_ kind: WidgetKind, onto target: WidgetKind) {
        guard kind != target,
              let from = placements.firstIndex(where: { $0.kind == kind }),
              let to = placements.firstIndex(where: { $0.kind == target }) else { return }
        let placement = placements.remove(at: from)
        placements.insert(placement, at: to)
        save()
    }

    func restoreDefaults() {
        placements = Self.defaultPlacements
        save()
    }

    private static var defaultPlacements: [WidgetPlacement] {
        WidgetKind.defaultLayout.map { WidgetPlacement(kind: $0, span: $0.defaultSpan) }
    }

    // The whole layout is written as one value, so a reader never sees a half-applied change.
    private func save() {
        let stored = placements.map { StoredPlacement(kind: $0.kind.rawValue, span: $0.span) }
        do {
            defaults.set(try JSONEncoder().encode(stored), forKey: Self.defaultsKey)
            lastError = nil
        } catch {
            lastError = "The widget layout could not be saved: \(error.localizedDescription)"
        }
    }

    private func load() -> [WidgetPlacement] {
        if let data = defaults.data(forKey: Self.defaultsKey) {
            do {
                let stored = try JSONDecoder().decode([StoredPlacement].self, from: data)
                return Self.placements(from: stored.map { ($0.kind, $0.span) })
            } catch {
                // Keep the unreadable value untouched until the user changes the layout.
                lastError = "The saved widget layout could not be read; showing the default widgets."
                return Self.defaultPlacements
            }
        }
        if let legacy = defaults.stringArray(forKey: Self.legacyDefaultsKey) {
            let migrated = Self.placements(from: legacy.map { ($0, nil) })
            placements = migrated
            save()
            return migrated
        }
        return Self.defaultPlacements
    }

    /// Drops kinds removed from the catalog and duplicates; a missing span gets the kind's default.
    private static func placements(from entries: [(kind: String, span: Int?)]) -> [WidgetPlacement] {
        var seen = Set<WidgetKind>()
        return entries.compactMap { entry in
            guard let kind = WidgetKind(rawValue: entry.kind), seen.insert(kind).inserted else { return nil }
            return WidgetPlacement(kind: kind, span: (entry.span ?? kind.defaultSpan).clamped(to: kind.spanRange))
        }
    }
}
