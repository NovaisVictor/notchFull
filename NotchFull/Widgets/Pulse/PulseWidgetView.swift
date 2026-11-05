import AppKit
import SwiftUI

struct PulseWidgetView: View {
    let sampler: PulseSampler
    let settings: PulseSettings

    @State private var isAppeared = false
    @State private var isWindowVisible = false
    /// Whether this view currently counts as an observer of the sampler; keeps activate/deactivate balanced.
    @State private var holdsActivation = false

    var body: some View {
        PulseContent(
            metrics: settings.visibleMetrics,
            readings: sampler.readings,
            history: sampler.history,
            style: settings.style,
            explainsOnHover: settings.explainsOnHover
        )
        // `onDisappear` alone misses a settings window that is closed but kept alive, so its occlusion counts too.
        .background(WindowVisibilityReader { isVisible in
            isWindowVisible = isVisible
            syncActivation()
        })
        .onAppear {
            isAppeared = true
            syncActivation()
        }
        .onDisappear {
            isAppeared = false
            syncActivation()
        }
    }

    private func syncActivation() {
        let shouldObserve = isAppeared && isWindowVisible
        guard shouldObserve != holdsActivation else { return }
        holdsActivation = shouldObserve
        if shouldObserve {
            sampler.activate()
        } else {
            sampler.deactivate()
        }
    }
}

/// The widget's face for a given set of readings; also drawn with sample values in the settings previews.
struct PulseContent: View {
    let metrics: [PulseMetric]
    let readings: [PulseMetric: PulseReading]
    let history: [PulseMetric: [Double]]
    let style: PulseStyle
    let explainsOnHover: Bool

    @State private var hovered: PulseMetric?

    var body: some View {
        if metrics.isEmpty {
            Text("No metrics enabled. Choose some in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let rows = layoutRows
            VStack(spacing: style == .rings ? 8 : 6) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 6) {
                        ForEach(rows[rowIndex]) { metric in
                            cell(for: metric)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(.rect)
                                .onHover { isHovering in
                                    if isHovering {
                                        hovered = metric
                                    } else if hovered == metric {
                                        hovered = nil
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: detailAlignment(rows: rows)) {
                if explainsOnHover, let hovered, metrics.contains(hovered) {
                    Text(reading(for: hovered).detail)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.85), in: .rect(cornerRadius: 8, style: .continuous))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.15), value: hovered)
        }
    }

    /// Up to three per row, two rows at most, so turning a metric off reflows the rest.
    private var layoutRows: [[PulseMetric]] {
        let columns = metrics.count <= 3 ? metrics.count : (metrics.count + 1) / 2
        return stride(from: 0, to: metrics.count, by: columns).map { Array(metrics[$0..<min($0 + columns, metrics.count)]) }
    }

    /// The detail goes on the side away from the hovered row so it never covers the metric it explains.
    private func detailAlignment(rows: [[PulseMetric]]) -> Alignment {
        guard rows.count > 1, let hovered, rows.last?.contains(hovered) == true else { return .bottom }
        return .top
    }

    private func reading(for metric: PulseMetric) -> PulseReading {
        readings[metric] ?? PulseReading(value: .measuring, detail: "\(metric.displayName): measuring…")
    }

    @ViewBuilder
    private func cell(for metric: PulseMetric) -> some View {
        switch style {
        case .rings: PulseRing(metric: metric, reading: reading(for: metric))
        case .graphs: PulseGraphCard(metric: metric, reading: reading(for: metric), points: history[metric] ?? [])
        }
    }
}

extension PulseMetric {
    /// Fixed per metric, so a ring is recognizable by color alone.
    var color: Color {
        switch self {
        case .cpu: .cyan
        case .ram: .green
        case .gpu: .purple
        case .disk: .orange
        case .battery: .yellow
        case .network: .blue
        }
    }
}

extension PulseReading {
    /// Text in the widget: a percentage, "↓16K ↑83K", or "—" when there is no valid number.
    var valueText: String {
        switch value {
        case let .fraction(fraction): PulseFormat.percent(fraction)
        case let .throughput(down, up): "↓\(PulseFormat.shortRate(down)) ↑\(PulseFormat.shortRate(up))"
        case .measuring, .unavailable: "—"
        }
    }

    var fraction: Double? {
        if case let .fraction(fraction) = value { fraction } else { nil }
    }
}

private struct PulseRing: View {
    let metric: PulseMetric
    let reading: PulseReading

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(metric.color.opacity(0.22), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: reading.fraction ?? 0)
                    .stroke(metric.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: reading.fraction)
                Image(systemName: metric.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(metric.color)
            }
            .frame(width: 32, height: 32)

            Text(reading.valueText)
                .font(.system(size: metric == .network ? 9 : 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(reading.fraction == nil && metric != .network ? .white.opacity(0.5) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct PulseGraphCard: View {
    let metric: PulseMetric
    let reading: PulseReading
    let points: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(metric.color)
                Text(reading.valueText)
                    .font(.system(size: metric == .network ? 9 : 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ZStack {
                Sparkline(points: points, ceiling: ceiling, isClosed: true)
                    .fill(metric.color.opacity(0.25).gradient)
                Sparkline(points: points, ceiling: ceiling, isClosed: false)
                    .stroke(metric.color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 10, style: .continuous))
    }

    /// Percentages share a fixed scale; throughput scales to its recent peak, with a floor so idle noise stays flat.
    private var ceiling: Double {
        metric == .network ? max(points.max() ?? 0, 10 * 1024) : 1
    }
}

/// The recent history, newest point at the right edge; the full width holds `PulseSampler.historyLength` points.
private struct Sparkline: Shape {
    let points: [Double]
    let ceiling: Double
    /// Closed down to the bottom edge, for the area under the line.
    let isClosed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1, ceiling > 0 else { return path }
        let step = rect.width / CGFloat(PulseSampler.historyLength - 1)
        let startX = rect.maxX - CGFloat(points.count - 1) * step
        let locations = points.enumerated().map { index, point in
            CGPoint(x: startX + CGFloat(index) * step, y: rect.maxY - CGFloat(min(point / ceiling, 1)) * rect.height)
        }
        path.addLines(locations)
        if isClosed, let first = locations.first, let last = locations.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Reports whether the hosting window is on screen, following its occlusion state.
private struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityView {
        VisibilityView()
    }

    func updateNSView(_ view: VisibilityView, context: Context) {
        view.onChange = onChange
    }

    final class VisibilityView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?
        private var lastReported: Bool?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            if let window {
                observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.reportVisibility() }
                }
            }
            reportVisibility()
        }

        private func reportVisibility() {
            let isVisible = window?.occlusionState.contains(.visible) ?? false
            guard isVisible != lastReported else { return }
            lastReported = isVisible
            // Deferred so the SwiftUI state change never happens while SwiftUI is updating the view hierarchy.
            DispatchQueue.main.async { [onChange] in onChange?(isVisible) }
        }
    }
}

extension PreviewSamples {
    static let pulseReadings: [PulseMetric: PulseReading] = [
        .cpu: PulseReading(value: .fraction(0.28), detail: "CPU: 28% across 10 cores"),
        .ram: PulseReading(value: .fraction(0.78), detail: "RAM: 12.4 of 16 GB"),
        .gpu: PulseReading(value: .fraction(0.59), detail: "GPU: 59% busy"),
        .disk: PulseReading(value: .fraction(0.59), detail: "Disk: 292 GB of 494 GB used"),
        .battery: PulseReading(value: .fraction(1), detail: "Battery: 100%, on power adapter"),
        .network: PulseReading(
            value: .throughput(downBytesPerSecond: 16 * 1024, upBytesPerSecond: 83 * 1024),
            detail: "Network: 16 KB/s down, 83 KB/s up"
        ),
    ]

    static let pulseHistory: [PulseMetric: [Double]] = {
        let wave = { (base: Double, swing: Double, phase: Double) in
            (0..<PulseSampler.historyLength).map { base + swing * sin(Double($0) / 5 + phase) }
        }
        return [
            .cpu: wave(0.25, 0.12, 0),
            .ram: wave(0.75, 0.03, 1),
            .gpu: wave(0.5, 0.2, 2),
            .disk: wave(0.59, 0, 0),
            .battery: wave(1, 0, 0),
            .network: wave(60 * 1024, 40 * 1024, 3),
        ]
    }()
}
