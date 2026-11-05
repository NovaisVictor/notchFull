import AppKit
import Observation

/// How a note's text is stored on disk.
enum NoteFileFormat: String, Codable {
    /// Rich text: bold, italic, underline, sizes and colors.
    case rtfd
    /// Code-mode notes; highlighting is recomputed when shown, so there is nothing else to keep.
    case plainText

    var fileExtension: String {
        switch self {
        case .rtfd: "rtfd"
        case .plainText: "txt"
        }
    }
}

/// A note's entry in the index; the text itself lives in its own file.
struct NoteSummary: Identifiable, Codable, Equatable {
    let id: UUID
    /// First line of the text, kept in the index so menus never read note files.
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var format: NoteFileFormat

    init(id: UUID, createdAt: Date, format: NoteFileFormat) {
        self.id = id
        title = ""
        self.createdAt = createdAt
        updatedAt = createdAt
        self.format = format
    }

    // Index files from older versions may lack fields; they decode with neutral values.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        format = try container.decodeIfPresent(NoteFileFormat.self, forKey: .format) ?? .rtfd
    }

    var displayTitle: String {
        title.isEmpty ? "New Note" : title
    }
}

/// The latest change to a note and the editor that made it, so that editor does not reload its own typing.
struct NoteRevision: Equatable {
    var number: Int
    var origin: UUID?
}

/// Notes persisted as one file per note in `Application Support/NotchFull/Notes`, plus an `index.json` with their
/// order, titles and the note open last. Typing saves after a short pause; every write is atomic.
@MainActor
@Observable
final class NoteStore {
    static let saveDelay: Duration = .milliseconds(500)
    static let undoDuration: Duration = .seconds(5)
    private static let titleLength = 60

    struct DeletedNote {
        let summary: NoteSummary
        let content: NSAttributedString
        let index: Int
    }

    private(set) var notes: [NoteSummary] = []
    /// The note shown in the widget; remembered across launches.
    private(set) var currentID: UUID?
    /// Bumped on every content change; editors compare it to know when to reload.
    private(set) var revisions: [UUID: NoteRevision] = [:]
    /// Notes whose file could not be read. They stay listed and their files untouched, but cannot be edited.
    private(set) var unreadableIDs: Set<UUID> = []
    /// The last deleted note, offered back for a few seconds.
    private(set) var recentlyDeleted: DeletedNote?
    private var loadError: String?
    private var saveError: String?

    var lastError: String? { saveError ?? loadError }

    @ObservationIgnored private var contents: [UUID: NSAttributedString] = [:]
    @ObservationIgnored private let folder: URL?
    @ObservationIgnored private let settings: NotesSettings
    @ObservationIgnored private var dirtyIDs: Set<UUID> = []
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var undoExpiry: Task<Void, Never>?
    /// An index that could not be read lists notes this session cannot see, so it must never be overwritten.
    @ObservationIgnored private var canWriteIndex = true

    init(settings: NotesSettings, fileManager: FileManager = .default) {
        self.settings = settings
        do {
            let folder = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "NotchFull/Notes", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
        } catch {
            folder = nil
            loadError = "Notes cannot be saved: \(error.localizedDescription)"
            return
        }
        load()
        if notes.isEmpty && canWriteIndex {
            create()
        }

        // The store lives for the app's lifetime, so the observer is never removed. Quitting within the save delay
        // would otherwise lose the last words typed.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    var currentNote: NoteSummary? {
        notes.first { $0.id == currentID }
    }

    func note(_ id: UUID) -> NoteSummary? {
        notes.first { $0.id == id }
    }

    /// The note's text, or `nil` when it is unknown or its file could not be read.
    func content(of id: UUID) -> NSAttributedString? {
        contents[id]
    }

    func revision(of id: UUID) -> NoteRevision {
        revisions[id] ?? NoteRevision(number: 0, origin: nil)
    }

    func select(_ id: UUID) {
        guard currentID != id, notes.contains(where: { $0.id == id }) else { return }
        currentID = id
        saveIndex()
    }

    /// Adds an empty note, makes it current and returns it; `nil` when notes cannot be saved.
    @discardableResult
    func create() -> UUID? {
        guard folder != nil, canWriteIndex else { return nil }
        let note = NoteSummary(id: UUID(), createdAt: .now, format: settings.codeMode ? .plainText : .rtfd)
        notes.append(note)
        contents[note.id] = NSAttributedString()
        revisions[note.id] = NoteRevision(number: 0, origin: nil)
        currentID = note.id
        dirtyIDs.insert(note.id)
        saveNow()
        return note.id
    }

    /// Replaces a note's text after an edit in `origin`. The note's format follows the code mode at the time of the
    /// edit, so a rich note edited in code mode becomes plain text.
    func setContent(_ content: NSAttributedString, of id: UUID, origin: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !unreadableIDs.contains(id) else { return }
        contents[id] = content
        notes[index].title = Self.title(from: content.string)
        notes[index].updatedAt = .now
        notes[index].format = settings.codeMode ? .plainText : .rtfd
        revisions[id] = NoteRevision(number: revision(of: id).number + 1, origin: origin)
        dirtyIDs.insert(id)
        scheduleSave()
    }

    func delete(_ id: UUID) {
        guard canWriteIndex, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let summary = notes.remove(at: index)
        dirtyIDs.remove(id)
        revisions[id] = nil

        // An unreadable note has no text to offer back, and its file was never understood: it stays on disk.
        let wasReadable = unreadableIDs.remove(id) == nil
        recentlyDeleted = contents.removeValue(forKey: id).map { DeletedNote(summary: summary, content: $0, index: index) }
        if currentID == id {
            currentID = notes.indices.contains(index) ? notes[index].id : notes.last?.id
        }
        if notes.isEmpty {
            create()
        }
        saveNow()
        // Removed only once the index no longer lists it, so a failed index write never points at a missing file.
        if wasReadable && saveError == nil {
            removeFile(of: summary)
        }

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
        guard let deleted = recentlyDeleted else { return }
        undoExpiry?.cancel()
        recentlyDeleted = nil
        notes.insert(deleted.summary, at: min(deleted.index, notes.count))
        contents[deleted.summary.id] = deleted.content
        revisions[deleted.summary.id] = NoteRevision(number: 0, origin: nil)
        currentID = deleted.summary.id
        dirtyIDs.insert(deleted.summary.id)
        saveNow()
    }

    /// Writes pending changes right away instead of waiting for typing to pause.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let folder, canWriteIndex else { return }

        var failures: [String] = []
        for id in dirtyIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let note = note(id), let content = contents[id] else {
                dirtyIDs.remove(id)
                continue
            }
            do {
                try write(content, of: note, in: folder)
                dirtyIDs.remove(id)
            } catch {
                // Stays dirty, so the next save tries again.
                failures.append("“\(note.displayTitle)”: \(error.localizedDescription)")
            }
        }
        do {
            try writeIndex(in: folder)
        } catch {
            failures.append("index: \(error.localizedDescription)")
        }
        saveError = failures.isEmpty ? nil : "Notes could not be saved (\(failures.joined(separator: "; ")))"
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.saveDelay)
            } catch {
                // Typing continued; the newer task saves instead.
                return
            }
            self?.saveNow()
        }
    }

    private func saveIndex() {
        guard let folder, canWriteIndex else { return }
        do {
            try writeIndex(in: folder)
            saveError = nil
        } catch {
            saveError = "Notes could not be saved (index: \(error.localizedDescription))"
        }
    }

    // MARK: - Files

    private struct Index: Codable {
        var notes: [NoteSummary]
        var currentID: UUID?
    }

    private func load() {
        guard let folder else { return }
        let indexURL = folder.appending(path: "index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }

        let index: Index
        do {
            index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: indexURL))
        } catch {
            canWriteIndex = false
            loadError = "Notes could not be read: \(error.localizedDescription)"
            return
        }

        notes = index.notes
        var unreadable: [String] = []
        for note in index.notes {
            revisions[note.id] = NoteRevision(number: 0, origin: nil)
            do {
                contents[note.id] = try read(note, in: folder)
            } catch {
                // Keep the file untouched; saving would overwrite the user's text.
                unreadableIDs.insert(note.id)
                unreadable.append("“\(note.displayTitle)”: \(error.localizedDescription)")
            }
        }
        if !unreadable.isEmpty {
            loadError = "Some notes could not be read and were left untouched (\(unreadable.joined(separator: "; ")))"
        }
        currentID = index.currentID.flatMap { id in notes.contains { $0.id == id } ? id : nil } ?? notes.first?.id
    }

    private func fileURL(of note: NoteSummary, format: NoteFileFormat, in folder: URL) -> URL {
        folder.appending(path: "\(note.id.uuidString).\(format.fileExtension)")
    }

    private func read(_ note: NoteSummary, in folder: URL) throws -> NSAttributedString {
        let url = fileURL(of: note, format: note.format, in: folder)
        switch note.format {
        case .rtfd:
            return try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
        case .plainText:
            return NSAttributedString(string: try String(contentsOf: url, encoding: .utf8))
        }
    }

    private func write(_ content: NSAttributedString, of note: NoteSummary, in folder: URL) throws {
        let url = fileURL(of: note, format: note.format, in: folder)
        switch note.format {
        case .rtfd:
            let wrapper = try content.fileWrapper(
                from: NSRange(location: 0, length: content.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        case .plainText:
            try Data(content.string.utf8).write(to: url, options: .atomic)
        }

        // A note switches format when edited with the other code mode; the stale file would be read by nobody.
        let otherFormat: NoteFileFormat = note.format == .rtfd ? .plainText : .rtfd
        let staleURL = fileURL(of: note, format: otherFormat, in: folder)
        if FileManager.default.fileExists(atPath: staleURL.path) {
            try FileManager.default.removeItem(at: staleURL)
        }
    }

    private func writeIndex(in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Index(notes: notes, currentID: currentID))
            .write(to: folder.appending(path: "index.json"), options: .atomic)
    }

    private func removeFile(of note: NoteSummary) {
        guard let folder else { return }
        let url = fileURL(of: note, format: note.format, in: folder)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            saveError = "The deleted note’s file could not be removed: \(error.localizedDescription)"
        }
    }

    private static func title(from text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return String(firstLine.prefix(titleLength))
    }
}
