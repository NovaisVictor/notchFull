import SwiftUI

/// Battery glyph whose fill animates from empty to the current level when it appears.
struct PowerActivityLeadingView: View {
    let event: BatteryMonitor.Event
    let reading: BatteryMonitor.Reading

    @State private var shownLevel = 0.0
    @State private var boltScale = 0.4

    var body: some View {
        ZStack {
            BatteryGlyph(level: shownLevel, color: PowerActivityStyle.color(for: event, reading: reading))
                .frame(width: 24, height: 12)
            if event == .pluggedIn || event == .fullyCharged {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 1)
                    .scaleEffect(boltScale)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                shownLevel = reading.level
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45).delay(0.15)) {
                boltScale = 1
            }
        }
    }
}

struct PowerActivityTrailingView: View {
    let event: BatteryMonitor.Event
    let reading: BatteryMonitor.Reading

    var body: some View {
        Text(reading.level, format: .percent.precision(.fractionLength(0)))
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(PowerActivityStyle.color(for: event, reading: reading))
    }
}

enum PowerActivityStyle {
    static func color(for event: BatteryMonitor.Event, reading: BatteryMonitor.Reading) -> Color {
        switch event {
        case .pluggedIn, .fullyCharged: .green
        case .low: .red
        case .unplugged: reading.level <= 0.2 ? .red : .white
        }
    }
}

private struct BatteryGlyph: View {
    let level: Double
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color)
                            .frame(width: max(0, (proxy.size.width - 4) * level))
                            .padding(2)
                    }
                }
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.5))
                .frame(width: 1.5, height: 4)
        }
    }
}
