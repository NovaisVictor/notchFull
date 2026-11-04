import AppKit
import Observation

/// Tracks the most recently active music player and exposes its controls.
@MainActor
@Observable
final class NowPlayingStore {
    private(set) var nowPlaying: NowPlaying?
    private(set) var activePlayer: ScriptableMusicPlayer?
    private(set) var lastError: String?
    /// True while playing and for a grace period after pausing, so the live activity stays reachable to resume.
    private(set) var isActive = false

    /// How long a paused track keeps the live activity on screen.
    static let pausedGracePeriod: Duration = .seconds(30)

    @ObservationIgnored private let players: [ScriptableMusicPlayer]
    @ObservationIgnored private var pauseExpiry: Task<Void, Never>?

    init(players: [ScriptableMusicPlayer] = [.spotify, .appleMusic]) {
        self.players = players

        // Distributed notifications need no permission; only artwork and commands use Apple Events.
        // The store lives for the app's lifetime, so the observers are never removed.
        for player in players {
            DistributedNotificationCenter.default().addObserver(
                forName: player.playbackNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let update = notification.userInfo.flatMap(player.playbackUpdate(from:))
                MainActor.assumeIsolated { self?.handle(update, from: player) }
            }
        }

        Task { await loadInitialPlayback() }
    }

    func send(_ command: PlayerCommand) {
        guard let player = activePlayer else { return }
        Task {
            do {
                try await player.send(command)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func handle(_ update: PlaybackUpdate?, from player: ScriptableMusicPlayer) {
        guard let update else {
            lastError = "Unrecognized playback notification from \(player.displayName)."
            return
        }
        lastError = nil

        switch update {
        case .stopped:
            if activePlayer?.id == player.id {
                nowPlaying = nil
                updateActivity()
            }
        case let .track(track):
            show(track, from: player)
        }
    }

    private func show(_ track: NowPlaying, from player: ScriptableMusicPlayer) {
        let current = activePlayer?.id == player.id ? nowPlaying : nil
        activePlayer = player

        var updated = track
        updated.positionDate = .now
        // Notifications never carry artwork; keep the loaded one while the track is the same.
        if let current, current.trackKey == track.trackKey {
            updated.artwork = current.artwork
            updated.artworkTint = current.artworkTint
            updated.duration = track.duration ?? current.duration
            nowPlaying = updated
        } else {
            nowPlaying = updated
            loadArtwork(for: track.trackKey, from: player)
        }
        if track.position == nil {
            loadPosition(for: track.trackKey, from: player)
        }
        updateActivity()
    }

    private func loadPosition(for trackKey: String, from player: ScriptableMusicPlayer) {
        Task {
            do {
                let position = try await player.playbackPosition()
                guard activePlayer?.id == player.id, nowPlaying?.trackKey == trackKey else { return }
                nowPlaying?.position = position
                nowPlaying?.positionDate = .now
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func updateActivity() {
        pauseExpiry?.cancel()
        guard let nowPlaying else {
            isActive = false
            return
        }
        guard !nowPlaying.isPlaying else {
            isActive = true
            return
        }
        // Paused: stay active (if it was) until the grace period ends without playback resuming.
        pauseExpiry = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.pausedGracePeriod)
            } catch {
                // Cancelled by a newer playback update, which decides the state itself.
                return
            }
            self?.isActive = false
        }
    }

    private func loadArtwork(for trackKey: String, from player: ScriptableMusicPlayer) {
        Task {
            do {
                guard let data = try await player.artworkData() else { return }
                guard let image = NSImage(data: data) else {
                    lastError = "\(player.displayName) returned artwork in an unreadable format."
                    return
                }
                // The track may have changed while the artwork loaded.
                guard activePlayer?.id == player.id, nowPlaying?.trackKey == trackKey else { return }
                nowPlaying?.artwork = image
                nowPlaying?.artworkTint = ArtworkTint.dominantColor(of: image)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Players only notify on change, so read the state of whichever one is already playing at launch.
    private func loadInitialPlayback() async {
        for player in players where player.isRunning {
            do {
                if case let .track(track) = try await player.currentPlayback() {
                    show(track, from: player)
                    if track.isPlaying { return }
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
