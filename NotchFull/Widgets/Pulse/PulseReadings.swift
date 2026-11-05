import Foundation

/// The system measurements the Pulse widget can show. Raw values are persisted, so never rename a case.
enum PulseMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case ram
    case gpu
    case disk
    case battery
    case network

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: "CPU"
        case .ram: "RAM"
        case .gpu: "GPU"
        case .disk: "Disk"
        case .battery: "Battery"
        case .network: "Network"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: "cpu"
        case .ram: "memorychip"
        case .gpu: "cube.transparent"
        case .disk: "internaldrive"
        case .battery: "battery.75percent"
        case .network: "network"
        }
    }
}

/// What one metric shows right now, plus the sentence that explains it on hover.
struct PulseReading: Equatable, Sendable {
    enum Value: Equatable, Sendable {
        /// Rates need two samples; the first one only sets the baseline.
        case measuring
        /// 0...1
        case fraction(Double)
        case throughput(downBytesPerSecond: Double, upBytesPerSecond: Double)
        /// The system did not provide the metric; shown as "—", never as 0%.
        case unavailable
    }

    let value: Value
    let detail: String

    /// The number plotted in the graph style, or `nil` when there is nothing valid to plot.
    var plottedValue: Double? {
        switch value {
        case let .fraction(fraction): fraction
        case let .throughput(down, up): down + up
        case .measuring, .unavailable: nil
        }
    }
}

struct PulseReadError: Error, Equatable, Sendable {
    let message: String
}

/// Kernel CPU tick counters, one entry per core. The kernel keeps them as wrapping 32-bit counters.
struct CPUTicks: Equatable, Sendable {
    struct Core: Equatable, Sendable {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }

    let cores: [Core]
}

struct MemoryCounters: Equatable, Sendable {
    let activePages: UInt64
    let wiredPages: UInt64
    let compressedPages: UInt64
    let pageSize: UInt64
    let physicalMemory: UInt64
}

struct DiskCapacity: Equatable, Sendable {
    let totalBytes: Int64
    let availableBytes: Int64
}

/// Byte counters of the active `en*` interfaces at one instant. `if_data` keeps them as wrapping 32-bit counters.
struct NetworkCounters: Equatable, Sendable {
    struct Bytes: Equatable, Sendable {
        let received: UInt32
        let sent: UInt32
    }

    let interfaces: [String: Bytes]
    /// Seconds since boot when the counters were read; a monotonic clock, unaffected by clock changes.
    let uptime: TimeInterval
}

/// Turns raw counters into readings. Pure functions of their inputs, so they can be tested without the system.
enum PulseCalculations {
    static func cpu(previous: CPUTicks?, current: CPUTicks) -> (PulseReading, CPUTicks) {
        guard let previous, previous.cores.count == current.cores.count else {
            return (PulseReading(value: .measuring, detail: "CPU: measuring…"), current)
        }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for (before, after) in zip(previous.cores, current.cores) {
            // Wrapping subtraction keeps the delta right when a 32-bit counter overflows between samples.
            let coreBusy = UInt64(after.user &- before.user) + UInt64(after.system &- before.system) + UInt64(after.nice &- before.nice)
            busy += coreBusy
            total += coreBusy + UInt64(after.idle &- before.idle)
        }
        guard total > 0 else {
            return (PulseReading(value: .measuring, detail: "CPU: measuring…"), current)
        }
        let fraction = Double(busy) / Double(total)
        let detail = "CPU: \(PulseFormat.percent(fraction)) across \(current.cores.count) cores"
        return (PulseReading(value: .fraction(fraction), detail: detail), current)
    }

    static func ram(_ counters: MemoryCounters) -> PulseReading {
        guard counters.physicalMemory > 0 else {
            return PulseReading(value: .unavailable, detail: "RAM: the system reported no physical memory.")
        }
        let used = (counters.activePages + counters.wiredPages + counters.compressedPages) * counters.pageSize
        let fraction = min(Double(used) / Double(counters.physicalMemory), 1)
        let detail = "RAM: \(PulseFormat.gigabytes(used)) of \(PulseFormat.gigabytes(counters.physicalMemory)) GB"
        return PulseReading(value: .fraction(fraction), detail: detail)
    }

    /// `percent` is the driver's "Device Utilization %", 0...100.
    static func gpu(percent: Double) -> PulseReading {
        let fraction = min(max(percent / 100, 0), 1)
        return PulseReading(value: .fraction(fraction), detail: "GPU: \(PulseFormat.percent(fraction)) busy")
    }

    static func disk(_ capacity: DiskCapacity) -> PulseReading {
        guard capacity.totalBytes > 0 else {
            return PulseReading(value: .unavailable, detail: "Disk: the startup volume reported no capacity.")
        }
        let available = min(max(capacity.availableBytes, 0), capacity.totalBytes)
        let used = capacity.totalBytes - available
        let detail = "Disk: \(used.formatted(.byteCount(style: .file))) of \(capacity.totalBytes.formatted(.byteCount(style: .file))) used"
        return PulseReading(value: .fraction(Double(used) / Double(capacity.totalBytes)), detail: detail)
    }

    static func battery(_ reading: BatteryMonitor.Reading?) -> PulseReading {
        guard let reading else {
            return PulseReading(value: .unavailable, detail: "Battery: this Mac has no internal battery.")
        }
        let state = reading.isCharging ? "charging" : reading.isOnACPower ? "on power adapter" : "on battery"
        return PulseReading(value: .fraction(reading.level), detail: "Battery: \(PulseFormat.percent(reading.level)), \(state)")
    }

    static func network(previous: NetworkCounters?, current: NetworkCounters) -> (PulseReading, NetworkCounters) {
        guard !current.interfaces.isEmpty else {
            return (PulseReading(value: .unavailable, detail: "Network: no active Wi-Fi or Ethernet interface."), current)
        }
        guard let previous, current.uptime > previous.uptime else {
            return (PulseReading(value: .measuring, detail: "Network: measuring…"), current)
        }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        // Interfaces that came up since the last sample have no baseline yet and are counted from the next one.
        for (name, after) in current.interfaces {
            guard let before = previous.interfaces[name] else { continue }
            received += UInt64(after.received &- before.received)
            sent += UInt64(after.sent &- before.sent)
        }
        let elapsed = current.uptime - previous.uptime
        let down = Double(received) / elapsed
        let up = Double(sent) / elapsed
        let detail = "Network: \(PulseFormat.longRate(down)) down, \(PulseFormat.longRate(up)) up"
        return (PulseReading(value: .throughput(downBytesPerSecond: down, upBytesPerSecond: up), detail: detail), current)
    }
}

enum PulseFormat {
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Binary gigabytes, because that is how macOS sizes installed memory ("16 GB").
    static func gigabytes(_ bytes: UInt64) -> String {
        (Double(bytes) / 1_073_741_824).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Compact rate for the widget: "16K", "1.2M".
    static func shortRate(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var value = max(bytesPerSecond, 0)
        var index = 0
        // Switching units at 1000 keeps the text at three digits at most ("1000K" never appears).
        while value >= 1000, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let number = index > 0 && value < 10
            ? value.formatted(.number.precision(.fractionLength(0...1)))
            : value.formatted(.number.precision(.fractionLength(0)))
        return number + units[index]
    }

    static func longRate(_ bytesPerSecond: Double) -> String {
        Int64(max(bytesPerSecond, 0).rounded()).formatted(.byteCount(style: .file)) + "/s"
    }
}
