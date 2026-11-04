import Foundation
import Observation

/// Which system events appear as live activities; each change is persisted immediately.
@MainActor
@Observable
final class ActivitySettings {
    static let lowBatteryRange = 0.05...0.5
    static let calendarLeadOptions = [5, 10, 15, 30]

    private enum Key {
        static let showsOnPlugIn = "activity.battery.plugIn"
        static let showsOnUnplug = "activity.battery.unplug"
        static let showsWhenFull = "activity.battery.full"
        static let showsLowBattery = "activity.battery.low"
        static let lowBatteryThreshold = "activity.battery.lowThreshold"
        static let showsBluetooth = "activity.bluetooth"
        static let showsDownloads = "activity.downloads"
        static let showsUpcomingEvents = "activity.calendar"
        static let calendarLeadMinutes = "activity.calendar.leadMinutes"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showsOnPlugIn: Bool { didSet { defaults.set(showsOnPlugIn, forKey: Key.showsOnPlugIn) } }
    var showsOnUnplug: Bool { didSet { defaults.set(showsOnUnplug, forKey: Key.showsOnUnplug) } }
    var showsWhenFull: Bool { didSet { defaults.set(showsWhenFull, forKey: Key.showsWhenFull) } }
    var showsLowBattery: Bool { didSet { defaults.set(showsLowBattery, forKey: Key.showsLowBattery) } }
    /// 0...1
    var lowBatteryThreshold: Double { didSet { defaults.set(lowBatteryThreshold, forKey: Key.lowBatteryThreshold) } }
    var showsBluetooth: Bool { didSet { defaults.set(showsBluetooth, forKey: Key.showsBluetooth) } }
    var showsDownloads: Bool { didSet { defaults.set(showsDownloads, forKey: Key.showsDownloads) } }
    var showsUpcomingEvents: Bool { didSet { defaults.set(showsUpcomingEvents, forKey: Key.showsUpcomingEvents) } }
    var calendarLeadMinutes: Int { didSet { defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsOnPlugIn = defaults.value(forKey: Key.showsOnPlugIn, default: true)
        showsOnUnplug = defaults.value(forKey: Key.showsOnUnplug, default: true)
        showsWhenFull = defaults.value(forKey: Key.showsWhenFull, default: true)
        showsLowBattery = defaults.value(forKey: Key.showsLowBattery, default: true)
        lowBatteryThreshold = defaults.value(forKey: Key.lowBatteryThreshold, default: 0.2).clamped(to: Self.lowBatteryRange)
        showsBluetooth = defaults.value(forKey: Key.showsBluetooth, default: true)
        showsDownloads = defaults.value(forKey: Key.showsDownloads, default: true)
        showsUpcomingEvents = defaults.value(forKey: Key.showsUpcomingEvents, default: true)
        let lead = defaults.value(forKey: Key.calendarLeadMinutes, default: 15)
        calendarLeadMinutes = Self.calendarLeadOptions.contains(lead) ? lead : 15
    }

    func shows(_ event: BatteryMonitor.Event) -> Bool {
        switch event {
        case .pluggedIn: showsOnPlugIn
        case .unplugged: showsOnUnplug
        case .fullyCharged: showsWhenFull
        case .low: showsLowBattery
        }
    }
}
