import SwiftUI

/// Single-line text that is centered when it fits and scrolls continuously, like a ticker, when it does not.
struct MarqueeText: View {
    /// Gap between the end of the text and its next repetition while scrolling.
    var spacing: CGFloat = 32
    /// Points per second.
    var speed: Double = 30
    /// Pause at the start of each loop so the beginning is readable.
    var startDelay: Double = 1.2
    let text: () -> Text

    @State private var textWidth: CGFloat = 0
    @State private var startDate = Date.now

    init(spacing: CGFloat = 32, speed: Double = 30, startDelay: Double = 1.2, text: @escaping () -> Text) {
        self.spacing = spacing
        self.speed = speed
        self.startDelay = startDelay
        self.text = text
    }

    var body: some View {
        GeometryReader { proxy in
            let overflows = textWidth > proxy.size.width

            Group {
                if overflows {
                    TimelineView(.animation) { context in
                        HStack(spacing: spacing) {
                            label
                            label
                        }
                        .offset(x: -offset(at: context.date))
                    }
                    .frame(width: proxy.size.width, alignment: .leading)
                    .mask(edgeFade)
                } else {
                    label
                        .frame(width: proxy.size.width)
                }
            }
            .frame(height: proxy.size.height)
        }
        .clipped()
        .background {
            // Measures the natural width once, independently of the visible frame.
            label
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    textWidth = width
                    startDate = .now
                }
        }
    }

    private var label: some View {
        text()
            .lineLimit(1)
            .fixedSize()
    }

    private func offset(at date: Date) -> CGFloat {
        let loopLength = Double(textWidth + spacing)
        let scrollDuration = loopLength / speed
        let elapsed = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: startDelay + scrollDuration)
        let scrolled = max(0, elapsed - startDelay) * speed
        return CGFloat(scrolled)
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.94),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
