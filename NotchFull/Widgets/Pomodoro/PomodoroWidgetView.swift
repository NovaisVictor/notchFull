import SwiftUI

struct PomodoroWidgetView: View {
    let timer: PomodoroTimer
    let settings: PomodoroSettings
    let hapticsEnabled: Bool

    var body: some View {
        VStack(spacing: 6) {
            PhasePicker(timer: timer)

            MinuteRuler(
                minutes: settings.minutes(for: timer.phase),
                range: timer.phase == .focus ? 5...60 : 1...30,
                isEnabled: timer.state == .idle && !timer.usesStopwatch,
                hapticsEnabled: hapticsEnabled
            ) { settings.setMinutes($0, for: timer.phase) }
            .frame(height: 34)

            HStack(spacing: 8) {
                RoundIconButton(systemImage: timer.isRunning ? "pause.fill" : "play.fill", isProminent: true) {
                    timer.toggle()
                }
                RoundIconButton(systemImage: settings.playsChime ? "speaker.wave.2.fill" : "speaker.slash.fill", isProminent: settings.playsChime) {
                    settings.playsChime.toggle()
                }
                .help("Chime at the end of each phase")
                if timer.isActive {
                    RoundIconButton(systemImage: "arrow.counterclockwise", isProminent: false) { timer.reset() }
                        .help("Reset")
                } else {
                    RoundIconButton(systemImage: "stopwatch", isProminent: timer.usesStopwatch) {
                        timer.setUsesStopwatch(!timer.usesStopwatch)
                    }
                    .help("Stopwatch")
                }
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(PomodoroFormat.clock(timer.displayedTime(at: context.date)))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(PomodoroFormat.color(for: timer.phase))
                        .contentTransition(.numericText(countsDown: !timer.usesStopwatch))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            if let title = timer.taskTitle {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum PomodoroFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

    static func color(for phase: PomodoroTimer.Phase) -> Color {
        phase == .focus ? .orange : .green
    }
}

private struct PhasePicker: View {
    let timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 6) {
            chip("Focus", phase: .focus)
            chip("Break", phase: .rest)
        }
    }

    private func chip(_ title: String, phase: PomodoroTimer.Phase) -> some View {
        let isSelected = timer.phase == phase
        return Button {
            timer.select(phase)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? PomodoroFormat.color(for: phase) : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(isSelected ? PomodoroFormat.color(for: phase).opacity(0.2) : .white.opacity(0.08), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(timer.isActive)
    }
}

private struct RoundIconButton: View {
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isProminent ? .orange : .white.opacity(0.6))
                .frame(width: 28, height: 28)
                .background(isProminent ? Color.orange.opacity(0.2) : .white.opacity(0.08), in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

/// A ruler of minutes: drag sideways to pick; labels every 5 minutes, the value under the marker.
private struct MinuteRuler: View {
    let minutes: Int
    let range: ClosedRange<Int>
    let isEnabled: Bool
    let hapticsEnabled: Bool
    let onChange: (Int) -> Void

    private static let tickSpacing: CGFloat = 7

    @State private var dragStartMinutes: Int?

    var body: some View {
        Canvas { context, size in
            let center = size.width / 2
            for minute in range {
                let x = center + CGFloat(minute - minutes) * Self.tickSpacing
                guard x >= 0, x <= size.width else { continue }
                let isMajor = minute % 5 == 0
                let isCurrent = minute == minutes
                // Ticks fade toward the edges so the selected value stands out.
                let fade = 1 - min(abs(x - center) / center, 1) * 0.8
                let tickHeight: CGFloat = isCurrent ? 16 : isMajor ? 11 : 7
                let tick = Path(CGRect(x: x - (isCurrent ? 1 : 0.5), y: size.height - tickHeight - 6, width: isCurrent ? 2 : 1, height: tickHeight))
                context.fill(tick, with: .color(isCurrent ? .white : .orange.opacity(0.6 * fade)))

                if isMajor || isCurrent {
                    let label = Text("\(minute)")
                        .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                        .foregroundStyle(isCurrent ? Color.white : Color.orange.opacity(0.7 * fade))
                    context.draw(label, at: CGPoint(x: x, y: 5))
                }
            }
            var marker = Path()
            marker.move(to: CGPoint(x: center, y: size.height - 5))
            marker.addLine(to: CGPoint(x: center - 4, y: size.height))
            marker.addLine(to: CGPoint(x: center + 4, y: size.height))
            marker.closeSubpath()
            context.fill(marker, with: .color(.orange))
        }
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard isEnabled else { return }
                    let start = dragStartMinutes ?? minutes
                    dragStartMinutes = start
                    let delta = Int((-value.translation.width / Self.tickSpacing).rounded())
                    select(start + delta)
                }
                .onEnded { _ in dragStartMinutes = nil }
        )
        .sensoryFeedback(.alignment, trigger: minutes) { _, _ in hapticsEnabled }
    }

    private func select(_ value: Int) {
        let clamped = value.clamped(to: range)
        if clamped != minutes { onChange(clamped) }
    }
}
