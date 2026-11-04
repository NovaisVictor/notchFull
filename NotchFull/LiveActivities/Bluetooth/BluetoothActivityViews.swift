import SwiftUI

struct BluetoothActivityLeadingView: View {
    let device: BluetoothDevice

    @State private var appeared = false

    var body: some View {
        Image(systemName: device.kind.systemImage)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.white.opacity(device.isConnected ? 1 : 0.45))
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { appeared = true }
            }
    }
}

struct BluetoothActivityTrailingView: View {
    let device: BluetoothDevice

    var body: some View {
        Group {
            if !device.isConnected {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            } else if let level = device.batteryLevel {
                Text(level, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(level <= 0.2 ? .red : .green)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .contentTransition(.numericText())
    }
}
