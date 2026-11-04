import SwiftUI

struct MediaArtworkView: View {
    let artwork: NSImage?
    let cornerRadius: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                shape.fill(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .clipShape(shape)
        .padding(6)
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Visualizer slot; while hovered it turns into a play/pause button.
struct MediaTrailingView: View {
    let nowPlaying: NowPlayingStore
    let settings: MediaActivitySettings
    let spectrum: AudioSpectrumSource
    let isHovered: Bool
    let closedHeight: CGFloat

    var body: some View {
        ZStack {
            if isHovered {
                Button {
                    nowPlaying.send(.playPause)
                } label: {
                    Image(systemName: nowPlaying.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                MediaVisualizerView(nowPlaying: nowPlaying, settings: settings, spectrum: spectrum)
                    .frame(
                        width: MediaVisualizerMetrics.size(for: settings.effect, closedHeight: closedHeight).width,
                        height: MediaVisualizerMetrics.size(for: settings.effect, closedHeight: closedHeight).height
                    )
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
    }
}

enum MediaVisualizerMetrics {
    // Small, like a status glyph; GIFs and the circle get more room because they need it to read.
    static func size(for effect: MediaEffect, closedHeight: CGFloat) -> CGSize {
        switch effect {
        case .gif, .vibratingCircle: CGSize(width: closedHeight * 0.75, height: closedHeight * 0.75)
        case .wave: CGSize(width: closedHeight * 0.8, height: closedHeight * 0.45)
        case .spectrograph, .off: CGSize(width: closedHeight * 0.55, height: closedHeight * 0.42)
        }
    }
}

/// Feeds the selected effect with live levels from the player.
struct MediaVisualizerView: View {
    let nowPlaying: NowPlayingStore
    let settings: MediaActivitySettings
    let spectrum: AudioSpectrumSource

    var body: some View {
        let isPlaying = nowPlaying.nowPlaying?.isPlaying == true
        let tint = settings.tintsWithArtwork ? nowPlaying.nowPlaying?.artworkTint.map { Color(nsColor: $0) } : nil

        MediaEffectView(
            effect: settings.effect,
            barCount: settings.barCount,
            tint: tint ?? .white,
            gifURL: settings.gifURL,
            gifScale: settings.gifScale,
            isPlaying: isPlaying
        ) { count, time in
            guard isPlaying else { return Array(repeating: 0.08, count: count) }
            if case .capturing = spectrum.status {
                return spectrum.levels(count: count)
            }
            return SimulatedLevels.levels(count: count, time: time)
        }
    }
}

/// Draws one effect from a level provider; used by the notch and by settings previews.
struct MediaEffectView: View {
    let effect: MediaEffect
    let barCount: Int
    let tint: Color
    let gifURL: URL?
    let gifScale: Double
    let isPlaying: Bool
    /// Band levels (0...1) for a band count at a time.
    let levels: (_ count: Int, _ time: Double) -> [Float]

    var body: some View {
        switch effect {
        case .gif:
            GIFEffectView(url: gifURL, scale: gifScale)
        case .off:
            Color.clear
        case .spectrograph, .wave, .vibratingCircle:
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                switch effect {
                case .spectrograph:
                    SpectrographEffect(levels: levels(barCount, time), color: tint)
                case .wave:
                    WaveEffect(levels: levels(8, time), time: time, color: tint)
                default:
                    VibratingCircleEffect(levels: levels(8, time), time: time, color: tint)
                }
            }
        }
    }
}

/// Plausible motion for when the real audio is not captured (permission off or capture unavailable).
enum SimulatedLevels {
    static func levels(count: Int, time: Double) -> [Float] {
        (0..<count).map { index in
            let i = Double(index)
            let slow = sin(time * (1.7 + i * 0.37) + i * 1.3)
            let fast = sin(time * (4.1 + i * 0.53) + i * 2.1)
            return Float(0.45 + 0.3 * slow + 0.2 * fast).clamped(to: 0.08...1)
        }
    }
}
