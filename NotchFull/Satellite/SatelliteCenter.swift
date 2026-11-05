import Observation
import SwiftUI

/// Decides which floating satellites show next to the notch. A closed set, like live activities, so a new kind of
/// satellite is a new case the compiler makes every view handle.
@MainActor
@Observable
final class SatelliteCenter {
    enum Satellite: Hashable, Identifiable {
        case pomodoro

        var id: Self { self }
    }

    /// Diameter of one satellite at rest.
    static let diameter: CGFloat = 28
    /// Width of a hovered satellite, which expands into a capsule with more detail.
    static let expandedWidth: CGFloat = 96
    static let spacing: CGFloat = 6
    /// Gap between the notch band and the satellites.
    static let margin: CGFloat = 6

    private let timer: PomodoroTimer
    private let settings: PomodoroSettings

    init(timer: PomodoroTimer, settings: PomodoroSettings) {
        self.timer = timer
        self.settings = settings
    }

    /// Active satellites in display order, nearest to the notch first.
    var active: [Satellite] {
        var satellites: [Satellite] = []
        if settings.showsSatellite && timer.isActive {
            satellites.append(.pomodoro)
        }
        return satellites
    }
}

/// The row of satellites; the hovered one expands to show its detail.
struct SatelliteStrip: View {
    let center: SatelliteCenter
    let timer: PomodoroTimer
    let hovered: SatelliteCenter.Satellite?
    let onActivate: (SatelliteCenter.Satellite) -> Void

    var body: some View {
        HStack(spacing: SatelliteCenter.spacing) {
            ForEach(center.active) { satellite in
                Button {
                    onActivate(satellite)
                } label: {
                    content(for: satellite, isExpanded: hovered == satellite)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.3, anchor: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: center.active)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovered)
    }

    @ViewBuilder
    private func content(for satellite: SatelliteCenter.Satellite, isExpanded: Bool) -> some View {
        switch satellite {
        case .pomodoro:
            PomodoroSatellite(timer: timer, isExpanded: isExpanded)
        }
    }
}

private struct PomodoroSatellite: View {
    let timer: PomodoroTimer
    let isExpanded: Bool

    var body: some View {
        let diameter = SatelliteCenter.diameter

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = timer.displayedTime(at: context.date)
            HStack(spacing: 6) {
                ZStack {
                    PomodoroRing(timer: timer, lineWidth: 2.5)
                        .padding(3)
                    Text(isExpanded ? "" : Self.compact(seconds))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(width: diameter, height: diameter)

                if isExpanded {
                    Text(PomodoroFormat.clock(seconds))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(PomodoroFormat.color(for: timer.phase))
                        .padding(.trailing, 10)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .frame(height: diameter)
            .background(.black, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .opacity(timer.isRunning ? 1 : 0.7)
            .contentShape(.capsule)
        }
        .help(timer.taskTitle ?? (timer.phase == .focus ? "Focus" : "Break"))
    }

    /// Minutes while there are any, then seconds, so two characters always fit the circle.
    static func compact(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return total >= 60 ? "\(min(total / 60, 99))" : "\(total)s"
    }
}

/// Which satellite the pointer is over, owned by the window that tracks the pointer.
@MainActor
@Observable
final class SatelliteHoverState {
    var hovered: SatelliteCenter.Satellite?
}

/// Root view of a satellite window.
struct SatelliteHost: View {
    let center: SatelliteCenter
    let timer: PomodoroTimer
    let hover: SatelliteHoverState
    let onActivate: (SatelliteCenter.Satellite) -> Void

    var body: some View {
        SatelliteStrip(center: center, timer: timer, hovered: hover.hovered, onActivate: onActivate)
            .padding(2)
    }
}
