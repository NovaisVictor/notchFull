import Foundation
import Observation

/// Follows downloads into the user's Downloads folder through the progress that browsers publish for each file
/// (the same progress the Finder draws on icons). Safari and Chromium browsers publish it.
@MainActor
@Observable
final class DownloadsMonitor {
    struct Download: Identifiable, Equatable, Sendable {
        let id: UUID
        let fileName: String
        let startedAt: Date
        /// 0...1, or `nil` while the browser does not know the total size.
        var fraction: Double?
    }

    private(set) var downloads: [UUID: Download] = [:]
    private(set) var lastError: String?
    /// Called with the file name when a download finishes successfully.
    @ObservationIgnored var onFinished: ((String) -> Void)?

    @ObservationIgnored private var subscriber: Any?

    init() {
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            lastError = "The Downloads folder could not be located."
            return
        }
        // The monitor lives for the app's lifetime, so the subscription is never removed.
        subscriber = Progress.addSubscriber(forFileURL: folder, withPublishingHandler: Self.makePublishingHandler(monitor: self))
    }

    /// The most recently started download still in progress.
    var current: Download? {
        downloads.values.max { $0.startedAt < $1.startedAt }
    }

    private func update(id: UUID, fileName: String, fraction: Double?) {
        if var download = downloads[id] {
            download.fraction = fraction
            downloads[id] = download
        } else {
            downloads[id] = Download(id: id, fileName: fileName, startedAt: .now, fraction: fraction)
        }
    }

    private func finish(id: UUID, completed: Bool) {
        guard let download = downloads.removeValue(forKey: id) else { return }
        if completed {
            onFinished?(download.fileName)
        }
    }

    // Built outside the main actor: Foundation calls these handlers on its own queues.
    nonisolated private static func makePublishingHandler(monitor: DownloadsMonitor) -> Progress.PublishingHandler {
        { progress in
            let id = UUID()
            let fileName = displayName(for: progress.fileURL)

            let observation = progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
                let fraction = progress.isIndeterminate ? nil : progress.fractionCompleted
                Task { @MainActor in monitor.update(id: id, fileName: fileName, fraction: fraction) }
            }
            return {
                observation.invalidate()
                let completed = !progress.isCancelled && progress.fractionCompleted >= 0.999
                Task { @MainActor in monitor.finish(id: id, completed: completed) }
            }
        }
    }

    /// File name without the browser's in-progress suffix.
    nonisolated private static func displayName(for url: URL?) -> String {
        guard let url else { return "Download" }
        let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial"]
        let trimmed = partialExtensions.contains(url.pathExtension.lowercased()) ? url.deletingPathExtension() : url
        return trimmed.lastPathComponent
    }
}
