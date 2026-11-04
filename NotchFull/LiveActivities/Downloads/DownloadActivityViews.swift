import SwiftUI

struct DownloadActivityLeadingView: View {
    /// `nil` while the size is unknown.
    let fraction: Double?

    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: fraction ?? 0.25)
                .stroke(.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(fraction == nil && spin ? 270 : -90))
                .animation(fraction == nil ? .linear(duration: 1).repeatForever(autoreverses: false) : .smooth, value: spin)
                .animation(.smooth, value: fraction)
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.blue)
        }
        .frame(width: 18, height: 18)
        .onAppear { spin = true }
    }
}

struct DownloadActivityTrailingView: View {
    let fraction: Double?

    var body: some View {
        Group {
            if let fraction {
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .contentTransition(.numericText(value: fraction))
                    .animation(.smooth, value: fraction)
            } else {
                Text("…")
            }
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.9))
    }
}

struct DownloadFinishedLeadingView: View {
    @State private var appeared = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 17))
            .foregroundStyle(.white, .green)
            .scaleEffect(appeared ? 1 : 0.4)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { appeared = true }
            }
    }
}

struct DownloadFinishedTrailingView: View {
    var body: some View {
        Text("Done")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.green)
    }
}
