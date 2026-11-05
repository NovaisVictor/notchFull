import SwiftUI

struct MusicWidgetView: View {
    let store: NowPlayingStore
    let layout: MusicWidgetLayout

    var body: some View {
        MusicCardContent(
            track: store.nowPlaying,
            appIcon: store.activePlayer?.applicationIcon,
            layout: layout,
            error: store.lastError,
            onCommand: store.send
        )
    }
}

/// Music card drawn from plain values, so settings can preview it with sample data.
struct MusicCardContent: View {
    let track: NowPlaying?
    let appIcon: NSImage?
    let layout: MusicWidgetLayout
    var error: String?
    let onCommand: (PlayerCommand) -> Void

    var body: some View {
        if let track {
            GeometryReader { proxy in
                // Narrow cards shrink the artwork and tighten the controls instead of pushing them out of the card.
                let artworkSide = min(proxy.size.height, proxy.size.width * 0.42)
                let isCompact = proxy.size.width - artworkSide < 150
                HStack(spacing: isCompact ? 10 : 14) {
                    artwork(for: track)
                        .frame(width: artworkSide, height: artworkSide)

                    VStack(spacing: 6) {
                        VStack(spacing: 1) {
                            Text(track.title)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        controls(isPlaying: track.isPlaying, isCompact: isCompact)
                        if layout == .expanded {
                            MusicProgressView(track: track, showsTimes: !isCompact)
                        }
                        if let error {
                            Text(error)
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .help(error)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                Text("Nothing playing")
                    .font(.system(size: 12, weight: .semibold))
                Text("Play something in Spotify or Music.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func artwork(for track: NowPlaying) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Group {
            if let artwork = track.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                shape.fill(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .clipShape(shape)
        .overlay(alignment: .bottomTrailing) {
            if layout == .expanded, let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(x: 6, y: 6)
            }
        }
    }

    private func controls(isPlaying: Bool, isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 6 : 20) {
            controlButton("backward.fill", size: 15, command: .previousTrack)
            controlButton(isPlaying ? "pause.fill" : "play.fill", size: 22, command: .playPause)
            controlButton("forward.fill", size: 15, command: .nextTrack)
        }
    }

    private func controlButton(_ systemImage: String, size: CGFloat, command: PlayerCommand) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct MusicProgressView: View {
    let track: NowPlaying
    /// Elapsed and remaining times; hidden on narrow cards, where they would squeeze the bar to nothing.
    var showsTimes = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = track.elapsed(at: context.date)
            HStack(spacing: 8) {
                if showsTimes {
                    Text(Self.format(elapsed))
                }
                Capsule()
                    .fill(.white.opacity(0.2))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(.white.opacity(0.85))
                                .frame(width: proxy.size.width * fraction(elapsed))
                        }
                    }
                    .frame(height: 4)
                if showsTimes {
                    Text(remaining(elapsed))
                }
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func fraction(_ elapsed: TimeInterval?) -> CGFloat {
        guard let elapsed, let duration = track.duration, duration > 0 else { return 0 }
        return CGFloat(min(elapsed / duration, 1))
    }

    private func remaining(_ elapsed: TimeInterval?) -> String {
        guard let elapsed, let duration = track.duration else { return "--:--" }
        return "-" + Self.format(max(duration - elapsed, 0))
    }

    static func format(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "--:--" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
