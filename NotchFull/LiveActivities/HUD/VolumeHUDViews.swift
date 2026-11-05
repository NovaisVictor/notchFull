import SwiftUI

enum VolumeHUDMetrics {
    /// Extra width on each side in the embedded style, so the device name and the number fit beside the camera.
    static let embeddedExtraWidth: CGFloat = 58
    /// Height of the row the classic style adds below the notch.
    static let classicHeight: CGFloat = 30
}

/// Embedded style, left of the camera: speaker icon and "Volume" or the output device's name.
struct VolumeEmbeddedLeadingView: View {
    let state: VolumeState

    var body: some View {
        HStack(spacing: 6) {
            VolumeIcon(state: state)
            Text(state.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }
}

/// Embedded style, right of the camera: a mini bar and the level as a number.
struct VolumeEmbeddedTrailingView: View {
    let state: VolumeState

    var body: some View {
        HStack(spacing: 7) {
            VolumeBar(level: state.shownLevel, height: 4)
                .frame(width: 40)
            Text("\(VolumeHUDFormat.percent(state.shownLevel))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: 26, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
    }
}

/// Classic style, below the notch: icon, a horizontal bar and the percentage.
struct VolumeClassicView: View {
    let state: VolumeState

    var body: some View {
        HStack(spacing: 10) {
            VolumeIcon(state: state)
            VolumeBar(level: state.shownLevel, height: 6)
            Text("\(VolumeHUDFormat.percent(state.shownLevel))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: 38, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}

private struct VolumeIcon: View {
    let state: VolumeState

    var body: some View {
        Image(systemName: state.systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(state.isMuted ? .white.opacity(0.55) : .white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 20, alignment: .leading)
    }
}

private struct VolumeBar: View {
    let level: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * level.clamped(to: 0...1))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: level)
    }
}

enum VolumeHUDFormat {
    static func percent(_ level: Double) -> Int {
        Int((level.clamped(to: 0...1) * 100).rounded())
    }
}
