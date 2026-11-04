import AppKit
import SwiftUI

struct SpectrographEffect: View {
    let levels: [Float]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let count = CGFloat(levels.count)
            guard count > 0 else { return }
            // Gaps are 60% of a bar, so n bars and n - 1 gaps fill the width exactly.
            let barWidth = size.width / (count + 0.6 * (count - 1))
            let gap = barWidth * 0.6

            for (index, level) in levels.enumerated() {
                let height = max(barWidth, size.height * CGFloat(level))
                let rect = CGRect(
                    x: CGFloat(index) * (barWidth + gap),
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
    }
}

/// A single thin waveform that glows and fades out toward both ends.
struct WaveEffect: View {
    let levels: [Float]
    let time: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let energy = CGFloat(levels.reduce(0, +)) / CGFloat(max(levels.count, 1))
            let path = Self.wavePath(in: size, energy: energy, time: time)
            let fade = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(0), location: 0),
                    .init(color: color, location: 0.3),
                    .init(color: color, location: 0.7),
                    .init(color: color.opacity(0), location: 1),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            )

            var glow = context
            glow.addFilter(.blur(radius: 2.5))
            glow.stroke(path, with: fade, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.stroke(path, with: fade, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    private static func wavePath(in size: CGSize, energy: CGFloat, time: Double) -> Path {
        var path = Path()
        let steps = 48
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let x = size.width * progress
            // Two detuned sines give an organic, non-repeating line.
            let phase = Double(progress) * 4 * .pi + time * 4
            let wobble = sin(phase) * 0.7 + sin(phase * 1.9 - time * 2.6) * 0.3
            let envelope = sin(.pi * Double(progress))
            let y = size.height / 2 + CGFloat(wobble * envelope) * (0.15 + energy) * size.height * 0.45
            step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// An outlined ring drawn as a few slightly different loops, so it reads like a hand-drawn circle that vibrates.
struct VibratingCircleEffect: View {
    let levels: [Float]
    let time: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let energy = CGFloat(levels.reduce(0, +)) / CGFloat(max(levels.count, 1))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * 0.36

            for stroke in 0..<3 {
                let seed = Double(stroke) * 1.7
                var path = Path()
                let points = 56
                for point in 0...points {
                    let angle = Double(point) / Double(points) * 2 * .pi
                    // Layered sines act as cheap periodic noise around the ring.
                    let wobble = sin(angle * 3 + time * 2.3 + seed) * 0.5
                        + sin(angle * 5 - time * 3.1 + seed) * 0.3
                        + sin(angle * 2 + time * 1.7 - seed) * 0.2
                    let radius = baseRadius * (1 + CGFloat(wobble) * (0.05 + energy * 0.22))
                    let position = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                    point == 0 ? path.move(to: position) : path.addLine(to: position)
                }
                path.closeSubpath()
                context.stroke(path, with: .color(color.opacity(stroke == 0 ? 0.9 : 0.4)), lineWidth: stroke == 0 ? 1.3 : 0.8)
            }
        }
    }
}

struct GIFEffectView: View {
    let url: URL?
    let scale: Double

    var body: some View {
        if let url {
            AnimatedImageView(url: url)
                .scaleEffect(scale)
        } else {
            Image(systemName: "photo")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .help("Choose a GIF in Settings → Live Activities.")
        }
    }
}

/// SwiftUI `Image` does not animate GIFs; `NSImageView` does.
private struct AnimatedImageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.animates = true
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        guard view.toolTip != url.path else { return }
        view.toolTip = url.path
        if let image = NSImage(contentsOf: url) {
            view.image = image
        } else {
            view.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "GIF could not be loaded")
            view.toolTip = "Could not load \(url.lastPathComponent)"
        }
    }
}
