import Foundation
import Observation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    /// Planned focus time, shown as a chip and used to start the Pomodoro for this task.
    var focusMinutes: Int?
    var isPriority: Bool
    /// Manual order; fractional so a move only rewrites the moved item.
    var sortOrder: Double
    var completedAt: Date?
    var archivedAt: Date?

    init(id: UUID, title: String, createdAt: Date, sortOrder: Double) {
        self.id = id
        self.title = title
        isDone = false
        self.createdAt = createdAt
        focusMinutes = nil
        isPriority = false
        self.sortOrder = sortOrder
        completedAt = nil
        archivedAt = nil
    }

    // Files written before these fields existed lack them; they decode with neutral values.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes)
        isPriority = try container.decodeIfPresent(Bool.self, forKey: .isPriority) ?? false
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder) ?? createdAt.timeIntervalSinceReferenceDate
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

/// To-do list persisted as one JSON file, written atomically after every change.
@MainActor
@Observable
final class TodoStore {
    private(set) var items: [TodoItem] = []
    private(set) var lastError: String?
    /// The last deleted item, offered back for a few seconds.
    private(set) var recentlyDeleted: TodoItem?

    static let undoDuration: Duration = .seconds(5)

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let settings: TodoSettings
    @ObservationIgnored private var undoExpiry: Task<Void, Never>?

    init(settings: TodoSettings, fileManager: FileManager = .default) {
        self.settings = settings
        do {
            let folder = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "NotchFull", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            fileURL = folder.appending(path: "todos.json")
        } catch {
            fileURL = nil
            lastError = "To-dos cannot be saved: \(error.localizedDescription)"
            return
        }
        load()
        archiveExpired()

        // The store lives for the app's lifetime, so the observer is never removed.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.archiveExpired() }
        }
    }

    /// Items in the widget, in manual order; completed ones are hidden when the setting says so.
    var visibleItems: [TodoItem] {
        items
            .filter { $0.archivedAt == nil && (settings.showsCompleted || !$0.isDone) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var archivedItems: [TodoItem] {
        items
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let last = items.map(\.sortOrder).max() ?? 0
        items.append(TodoItem(id: UUID(), title: trimmed, createdAt: .now, sortOrder: last + 1))
        save()
    }

    func toggle(_ id: TodoItem.ID) {
        update(id) { item in
            item.isDone.toggle()
            item.completedAt = item.isDone ? .now : nil
        }
    }

    func setFocusMinutes(_ minutes: Int?, for id: TodoItem.ID) {
        update(id) { $0.focusMinutes = minutes }
    }

    func togglePriority(_ id: TodoItem.ID) {
        update(id) { $0.isPriority.toggle() }
    }

    /// Places `id` where `target` is among the visible items: after it when moving down, before it when moving up.
    func move(_ id: TodoItem.ID, onto target: TodoItem.ID) {
        let visible = visibleItems
        guard id != target,
              let from = visible.firstIndex(where: { $0.id == id }),
              let to = visible.firstIndex(where: { $0.id == target }) else { return }

        let neighbors: (Double?, Double?) = from < to
            ? (visible[to].sortOrder, visible.indices.contains(to + 1) ? visible[to + 1].sortOrder : nil)
            : (visible.indices.contains(to - 1) ? visible[to - 1].sortOrder : nil, visible[to].sortOrder)
        let newOrder: Double = switch neighbors {
        case let (before?, after?): (before + after) / 2
        case let (before?, nil): before + 1
        case let (nil, after?): after - 1
        case (nil, nil): 0
        }
        update(id) { $0.sortOrder = newOrder }
    }

    func delete(_ id: TodoItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        recentlyDeleted = items.remove(at: index)
        save()

        undoExpiry?.cancel()
        undoExpiry = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.undoDuration)
            } catch {
                // Replaced by a newer deletion or an undo, which own the state now.
                return
            }
            self?.recentlyDeleted = nil
        }
    }

    func undoDelete() {
        guard let item = recentlyDeleted else { return }
        undoExpiry?.cancel()
        recentlyDeleted = nil
        items.append(item)
        save()
    }

    func restore(_ id: TodoItem.ID) {
        update(id) { $0.archivedAt = nil }
    }

    func deleteArchived() {
        items.removeAll { $0.archivedAt != nil }
        save()
    }

    func archiveCompletedNow() {
        let now = Date.now
        for index in items.indices where items[index].isDone && items[index].archivedAt == nil {
            items[index].archivedAt = now
        }
        save()
    }

    /// Archives completed tasks older than the configured number of days.
    func archiveExpired(now: Date = .now) {
        let days = settings.autoArchiveDays
        guard days > 0, let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return }
        var changed = false
        for index in items.indices {
            guard items[index].isDone, items[index].archivedAt == nil,
                  let completedAt = items[index].completedAt, completedAt <= cutoff else { continue }
            items[index].archivedAt = now
            changed = true
        }
        if changed { save() }
    }

    private func update(_ id: TodoItem.ID, _ change: (inout TodoItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        save()
    }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            items = try JSONDecoder().decode([TodoItem].self, from: Data(contentsOf: fileURL))
        } catch {
            // Keep the unreadable file untouched; saving would overwrite the user's data.
            lastError = "To-dos could not be read: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "To-dos could not be saved: \(error.localizedDescription)"
        }
    }
}
