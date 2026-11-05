import SwiftUI

/// A small progress ring with the phase icon; shared by the closed notch and the floating satellite.
struct PomodoroRing: View {
    let timer: PomodoroTimer
    var lineWidth: CGFloat = 2.5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let color = PomodoroFormat.color(for: timer.phase)
            ZStack {
                Circle().stroke(color.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: timer.progress(at: context.date) ?? 1)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(timer.progress(at: context.date) == nil ? 0.5 : 1)
            }
            .animation(.linear(duration: 1), value: timer.progress(at: context.date))
        }
    }
}

struct PomodoroActivityLeadingView: View {
    let timer: PomodoroTimer

    var body: some View {
        ZStack {
            PomodoroRing(timer: timer)
            Image(systemName: timer.phase == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(PomodoroFormat.color(for: timer.phase))
        }
        .frame(width: 18, height: 18)
    }
}

struct PomodoroActivityTrailingView: View {
    let timer: PomodoroTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(PomodoroFormat.clock(timer.displayedTime(at: context.date)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timer.isRunning ? PomodoroFormat.color(for: timer.phase) : .white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
