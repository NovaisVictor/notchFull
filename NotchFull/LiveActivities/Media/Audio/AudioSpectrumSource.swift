import AppKit
import Observation

/// Owns the audio tap for the active player and exposes its frequency bands.
@MainActor
@Observable
final class AudioSpectrumSource {
    enum Status: Equatable {
        case idle
        case capturing(bundleIdentifier: String)
        case failed(String)
    }

    private(set) var status: Status = .idle
    @ObservationIgnored private var tap: ProcessAudioTap?
    @ObservationIgnored private let analyzer = SpectrumAnalyzer()

    /// Starts capturing `player`, switching taps if another player was captured; `nil` stops capture.
    func capture(_ player: ScriptableMusicPlayer?) {
        guard let player else {
            stop()
            return
        }
        if case let .capturing(bundleIdentifier) = status, bundleIdentifier == player.bundleIdentifier {
            return
        }

        stop()
        guard tap == nil else { return }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleIdentifier).first else {
            status = .failed("\(player.displayName) is not running.")
            return
        }

        do {
            tap = try ProcessAudioTap(pid: app.processIdentifier, analyzer: analyzer)
            status = .capturing(bundleIdentifier: player.bundleIdentifier)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func levels(count: Int) -> [Float] {
        analyzer.levels(count: count)
    }

    private func stop() {
        guard let tap else {
            status = .idle
            return
        }
        do {
            try tap.stop()
            self.tap = nil
            status = .idle
        } catch {
            // The tap keeps the resources it could not release; the next stop retries them.
            status = .failed(error.localizedDescription)
        }
    }
}
