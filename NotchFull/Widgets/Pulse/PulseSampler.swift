import Foundation
import Observation
import os

/// Samples the enabled metrics on the user's interval, only while at least one Pulse widget is on screen.
@MainActor
@Observable
final class PulseSampler {
    /// Points kept per metric for the graph style.
    nonisolated static let historyLength = 60
    /// The first rate needs a second sample; taking it sooner than the interval avoids a long "—" on open.
    private static let baselineDelay: Duration = .milliseconds(500)
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "pulse")

    private(set) var readings: [PulseMetric: PulseReading] = [:]
    private(set) var history: [PulseMetric: [Double]] = [:]
    /// Read failures of the last sample, one line per metric.
    private(set) var lastError: String?

    @ObservationIgnored private let settings: PulseSettings
    @ObservationIgnored private let battery: BatteryMonitor
    /// Widgets currently on screen; the notch and the settings preview can show one at the same time.
    @ObservationIgnored private var observers = 0
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var previousCPU: CPUTicks?
    @ObservationIgnored private var previousNetwork: NetworkCounters?

    init(settings: PulseSettings, battery: BatteryMonitor) {
        self.settings = settings
        self.battery = battery
    }

    func activate() {
        observers += 1
        if observers == 1 { start() }
    }

    func deactivate() {
        guard observers > 0 else {
            Self.log.fault("deactivate() called without a matching activate()")
            return
        }
        observers -= 1
        if observers == 0 { stop() }
    }

    private func start() {
        loop = Task { [weak self] in
            var delay = Self.baselineDelay
            while !Task.isCancelled {
                guard let self else { return }
                await self.sample()
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    // Cancellation is how `stop()` ends the loop.
                    return
                }
                delay = .seconds(self.settings.interval)
            }
        }
    }

    private func stop() {
        loop?.cancel()
        loop = nil
        // Rates measured across the hidden period would be averages over minutes; the next visit starts a new baseline.
        previousCPU = nil
        previousNetwork = nil
    }

    private func sample() async {
        let metrics = settings.enabledMetrics
        let snapshot = await Task.detached(priority: .utility) { PulseProbe.capture(metrics) }.value
        // The widget may have been hidden while the probe ran; a stopped sampler must not record a late sample.
        guard !Task.isCancelled else { return }
        apply(snapshot, metrics: metrics)
    }

    private func apply(_ snapshot: PulseProbe.Snapshot, metrics: Set<PulseMetric>) {
        var failures: [String] = []

        func reading<Sample>(_ result: Result<Sample, PulseReadError>?, _ compute: (Sample) -> PulseReading) -> PulseReading? {
            switch result {
            case nil:
                return nil
            case let .success(sample):
                return compute(sample)
            case let .failure(error):
                failures.append(error.message)
                return PulseReading(value: .unavailable, detail: error.message)
            }
        }

        if metrics.contains(.cpu) {
            record(.cpu, reading(snapshot.cpu) { ticks in
                let (reading, sample) = PulseCalculations.cpu(previous: previousCPU, current: ticks)
                previousCPU = sample
                return reading
            })
        } else {
            previousCPU = nil
        }
        if metrics.contains(.network) {
            record(.network, reading(snapshot.network) { counters in
                let (reading, sample) = PulseCalculations.network(previous: previousNetwork, current: counters)
                previousNetwork = sample
                return reading
            })
        } else {
            previousNetwork = nil
        }
        record(.ram, reading(snapshot.ram, PulseCalculations.ram))
        record(.gpu, reading(snapshot.gpu) { PulseCalculations.gpu(percent: $0) })
        record(.disk, reading(snapshot.disk, PulseCalculations.disk))
        if metrics.contains(.battery) {
            record(.battery, PulseCalculations.battery(battery.reading))
        }

        lastError = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    private func record(_ metric: PulseMetric, _ reading: PulseReading?) {
        guard let reading else { return }
        readings[metric] = reading
        guard let point = reading.plottedValue else { return }
        var points = history[metric, default: []]
        points.append(point)
        if points.count > Self.historyLength {
            points.removeFirst(points.count - Self.historyLength)
        }
        history[metric] = points
    }
}
