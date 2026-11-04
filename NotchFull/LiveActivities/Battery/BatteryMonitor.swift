import Foundation
import IOKit.ps
import Observation

/// Internal battery state, refreshed by IOKit power-source notifications.
@MainActor
@Observable
final class BatteryMonitor {
    struct Reading: Equatable {
        /// 0...1
        let level: Double
        let isCharging: Bool
        let isOnACPower: Bool
    }

    enum Event: Equatable {
        case pluggedIn
        case unplugged
        case fullyCharged
        case low

        /// The user-visible event between two consecutive readings, if any.
        static func detect(from previous: Reading, to current: Reading, lowThreshold: Double) -> Event? {
            if current.isOnACPower != previous.isOnACPower {
                return current.isOnACPower ? .pluggedIn : .unplugged
            }
            if current.isOnACPower, previous.level < 1, current.level >= 1 {
                return .fullyCharged
            }
            if !current.isOnACPower, previous.level > lowThreshold, current.level <= lowThreshold {
                return .low
            }
            return nil
        }
    }

    /// `nil` when the Mac has no internal battery or IOKit reports an incomplete description.
    private(set) var reading: Reading?
    /// Called with each pair of consecutive readings; not called for the initial reading.
    @ObservationIgnored var onChange: ((_ previous: Reading, _ current: Reading) -> Void)?

    init() {
        reading = Self.readInternalBattery()

        // The source lives on the main run loop for the app's lifetime, so `self` is never released before it.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func refresh() {
        let previous = reading
        let current = Self.readInternalBattery()
        reading = current

        guard let previous, let current, previous != current else { return }
        onChange?(previous, current)
    }

    private static func readInternalBattery() -> Reading? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int, max > 0,
                let isCharging = description[kIOPSIsChargingKey] as? Bool,
                let powerState = description[kIOPSPowerSourceStateKey] as? String
            else { continue }

            return Reading(
                level: Double(current) / Double(max),
                isCharging: isCharging,
                isOnACPower: powerState == kIOPSACPowerValue
            )
        }
        return nil
    }
}
