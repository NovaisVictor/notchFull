import AppKit

struct NowPlaying: Equatable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    var artwork: NSImage?
    /// Dominant artwork color, lifted for contrast on the black notch.
    var artworkTint: NSColor?
    var duration: TimeInterval?
    /// Playback position measured at `positionDate`; extrapolated while playing.
    var position: TimeInterval?
    var positionDate: Date = .now

    func elapsed(at date: Date) -> TimeInterval? {
        guard let position else { return nil }
        let elapsed = isPlaying ? position + date.timeIntervalSince(positionDate) : position
        return duration.map { min(elapsed, $0) } ?? elapsed
    }

    /// Identifies the track independently of play state, to keep artwork across play/pause updates.
    var trackKey: String {
        [title, artist, album].joined(separator: "\u{1F}")
    }
}

enum PlaybackUpdate: Equatable {
    case stopped
    case track(NowPlaying)
}

enum PlayerCommand {
    case playPause
    case nextTrack
    case previousTrack

    var appleScriptVerb: String {
        switch self {
        case .playPause: "playpause"
        case .nextTrack: "next track"
        case .previousTrack: "previous track"
        }
    }
}

enum MusicPlayerError: LocalizedError {
    case notRunning(String)
    case unexpectedScriptResult(String)
    case artworkDownloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case let .notRunning(name): "\(name) is not running."
        case let .unexpectedScriptResult(name): "\(name) returned an unexpected playback state."
        case let .artworkDownloadFailed(statusCode): "Artwork download failed (HTTP \(statusCode))."
        }
    }
}

/// A scriptable player that announces playback changes through a distributed notification.
/// Spotify and Music share the same playback vocabulary, so one type covers both; they differ only in
/// how artwork is exposed.
struct ScriptableMusicPlayer: Sendable, Identifiable {
    enum ArtworkSource: Sendable {
        /// Spotify returns an HTTPS URL for the cover.
        case url
        /// Music returns the image bytes of the track's first artwork.
        case embeddedData
    }

    static let spotify = ScriptableMusicPlayer(
        displayName: "Spotify",
        applicationName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        playbackNotification: Notification.Name("com.spotify.client.PlaybackStateChanged"),
        artworkSource: .url
    )

    static let appleMusic = ScriptableMusicPlayer(
        displayName: "Music",
        applicationName: "Music",
        bundleIdentifier: "com.apple.Music",
        playbackNotification: Notification.Name("com.apple.Music.playerInfo"),
        artworkSource: .embeddedData
    )

    let displayName: String
    let applicationName: String
    let bundleIdentifier: String
    let playbackNotification: Notification.Name
    let artworkSource: ArtworkSource

    var id: String { bundleIdentifier }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Parses the notification payload; `nil` means the payload was not recognized.
    func playbackUpdate(from userInfo: [AnyHashable: Any]) -> PlaybackUpdate? {
        guard let state = userInfo["Player State"] as? String else { return nil }
        if state == "Stopped" { return .stopped }
        guard let title = userInfo["Name"] as? String else { return nil }

        // Both players send the duration in milliseconds; only Spotify sends the position (in seconds).
        let durationMilliseconds = (userInfo["Duration"] ?? userInfo["Total Time"]) as? Double
        return .track(NowPlaying(
            title: title,
            artist: userInfo["Artist"] as? String ?? "",
            album: userInfo["Album"] as? String ?? "",
            isPlaying: state == "Playing",
            duration: durationMilliseconds.map { $0 / 1000 },
            position: userInfo["Playback Position"] as? Double
        ))
    }

    /// Reads the current state. Every script checks `isRunning` first: telling a closed app anything launches it.
    func currentPlayback() async throws -> PlaybackUpdate {
        guard isRunning else { throw MusicPlayerError.notRunning(displayName) }

        // Times are returned as integer milliseconds: real numbers would be formatted with the user's locale.
        let source = """
        tell application "\(applicationName)"
            if player state is stopped then return {}
            return {player state as string, name of current track, artist of current track, album of current track, \
        (player position * 1000) as integer, \(durationMillisecondsExpression)}
        end tell
        """
        let items = try await AppleScriptRunner.shared.run(source)
        if items.isEmpty { return .stopped }
        guard items.count == 6, let state = items[0], let title = items[1] else {
            throw MusicPlayerError.unexpectedScriptResult(displayName)
        }

        return .track(NowPlaying(
            title: title,
            artist: items[2] ?? "",
            album: items[3] ?? "",
            isPlaying: state == "playing",
            duration: items[5].flatMap(Double.init).map { $0 / 1000 },
            position: items[4].flatMap(Double.init).map { $0 / 1000 }
        ))
    }

    /// Current playback position in seconds.
    func playbackPosition() async throws -> TimeInterval? {
        guard isRunning else { throw MusicPlayerError.notRunning(displayName) }
        let items = try await AppleScriptRunner.shared.run(
            "tell application \"\(applicationName)\" to return (player position * 1000) as integer"
        )
        return items.first.flatMap { $0 }.flatMap(Double.init).map { $0 / 1000 }
    }

    var applicationIcon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier).map {
            NSWorkspace.shared.icon(forFile: $0.path)
        }
    }

    // Spotify reports the track duration in milliseconds, Music in seconds.
    private var durationMillisecondsExpression: String {
        artworkSource == .url ? "duration of current track" : "(duration of current track * 1000) as integer"
    }

    /// Image bytes of the current track's cover; `nil` when the track has none.
    func artworkData() async throws -> Data? {
        guard isRunning else { throw MusicPlayerError.notRunning(displayName) }

        switch artworkSource {
        case .url:
            let items = try await AppleScriptRunner.shared.run(
                "tell application \"\(applicationName)\" to return artwork url of current track"
            )
            guard let url = items.first.flatMap({ $0 }).flatMap(URL.init(string:)) else { return nil }
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw MusicPlayerError.artworkDownloadFailed(statusCode: http.statusCode)
            }
            return data

        case .embeddedData:
            return try await AppleScriptRunner.shared.runReturningData("""
            tell application "\(applicationName)"
                if (count of artworks of current track) is 0 then return missing value
                return data of artwork 1 of current track
            end tell
            """)
        }
    }

    func send(_ command: PlayerCommand) async throws {
        guard isRunning else { throw MusicPlayerError.notRunning(displayName) }
        _ = try await AppleScriptRunner.shared.run("tell application \"\(applicationName)\" to \(command.appleScriptVerb)")
    }
}
