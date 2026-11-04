import Foundation
import Observation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
}

/// To-do list persisted as one JSON file, written atomically after every change.
@MainActor
@Observable
final class TodoStore {
    private(set) var items: [TodoItem] = []
    private(set) var lastError: String?

    @ObservationIgnored private let fileURL: URL?

    init(fileManager: FileManager = .default) {
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
    }

    /// Open items first, oldest on top; completed items after them.
    var sortedItems: [TodoItem] {
        items.sorted { lhs, rhs in
            lhs.isDone == rhs.isDone ? lhs.createdAt < rhs.createdAt : !lhs.isDone
        }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(id: UUID(), title: trimmed, isDone: false, createdAt: .now))
        save()
    }

    func toggle(_ id: TodoItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        save()
    }

    func delete(_ id: TodoItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearCompleted() {
        items.removeAll(where: \.isDone)
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
