import AppKit
import ApplicationServices
import CoreGraphics
import IOKit.hidsystem
import Observation
import os

/// A volume key press read from the keyboard's media row.
struct MediaKeyPress {
    enum Key {
        case volumeUp
        case volumeDown
        case mute

        /// Holding mute does not toggle it again and again; holding a volume key keeps stepping.
        var repeats: Bool { self != .mute }
    }

    let key: Key
    /// Option and Shift held: macOS moves the volume in quarter steps.
    let isFine: Bool
}

/// Owns the event tap that reads the volume keys before macOS does, so a handled key never reaches the system HUD.
/// The tap needs the Accessibility permission; without it nothing is created and the keys work as before.
@MainActor
@Observable
final class MediaKeyTap {
    private(set) var isTrusted: Bool
    private(set) var isRunning = false
    private(set) var lastError: String?
    /// Returns whether the press was handled. Handled presses are consumed; the rest go to macOS unchanged.
    @ObservationIgnored var onKeyDown: ((MediaKeyPress) -> Bool)?

    private static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "media-keys")
    /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`: the system-defined events that carry media keys.
    nonisolated private static let mediaKeySubtype: Int16 = 8

    @ObservationIgnored private var port: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    /// Keys whose key-down was consumed; their repeats and key-up are consumed too, so macOS never sees half a press.
    @ObservationIgnored private var consumedKeyCodes: Set<Int> = []

    init() {
        isTrusted = AXIsProcessTrusted()
        // macOS sends no notification when the permission changes. The user grants it in System Settings and comes
        // back to NotchFull, so checking on activation catches the change without polling.
        // The tap lives for the app's lifetime, so the observer is never removed.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTrust() }
        }
    }

    func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        Self.log.info("Accessibility permission changed: trusted=\(trusted, privacy: .public)")
    }

    /// Shows the system prompt that sends the user to the Accessibility list; it appears once per app.
    func requestAccess() {
        // The value of `kAXTrustedCheckOptionPrompt`, which Swift 6 imports as a mutable global it refuses to read.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = Self.accessibilitySettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    func start() {
        guard port == nil, isTrusted else { return }
        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "Could not listen to the volume keys. Remove NotchFull from Accessibility, add it again and retry."
            Self.log.error("CGEvent.tapCreate returned nil while trusted")
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            lastError = "Could not attach the volume key listener to the main run loop."
            Self.log.error("CFMachPortCreateRunLoopSource returned nil")
            return
        }
        // The main run loop makes the callback run on the main thread, which is what lets it assume main-actor isolation.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        isRunning = true
        lastError = nil
        Self.log.info("Media key tap started")
    }

    func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
        consumedKeyCodes = []
        isRunning = false
        Self.log.info("Media key tap stopped")
    }

    /// What the callback needs from an event, copied out of the non-sendable `CGEvent` before reaching the main actor.
    private enum TapInput: Sendable {
        case tapDisabled(CGEventType)
        case mediaKey(MediaKeyEvent)
        case other
    }

    private struct MediaKeyEvent: Sendable {
        let keyCode: Int
        let isKeyDown: Bool
        let isRepeat: Bool
        let flags: CGEventFlags
    }

    // A C function pointer cannot capture context: the owner arrives through `refcon`. Built nonisolated because
    // the tap calls it as a plain C function; the main run loop source guarantees it runs on the main thread.
    nonisolated private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        let input = decode(type: type, event: event)
        if case .other = input { return Unmanaged.passUnretained(event) }
        guard let refcon else { return Unmanaged.passUnretained(event) }
        // Only dereferenced on the main thread, where the owner lives; the tap's run loop source is never elsewhere.
        nonisolated(unsafe) let owner = refcon
        let consumes = MainActor.assumeIsolated {
            Unmanaged<MediaKeyTap>.fromOpaque(owner).takeUnretainedValue().handle(input)
        }
        return consumes ? nil : Unmanaged.passUnretained(event)
    }

    nonisolated private static func decode(type: CGEventType, event: CGEvent) -> TapInput {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled(type)
        case CGEventType(rawValue: UInt32(NSEvent.EventType.systemDefined.rawValue)):
            guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == mediaKeySubtype else { return .other }
            // Layout of `data1` for media keys: key code in the high 16 bits, then key state and the repeat bit.
            let data1 = nsEvent.data1
            let keyFlags = data1 & 0xFFFF
            return .mediaKey(MediaKeyEvent(
                keyCode: (data1 & 0xFFFF0000) >> 16,
                isKeyDown: ((keyFlags & 0xFF00) >> 8) == 0xA,
                isRepeat: (keyFlags & 0x1) != 0,
                flags: event.flags
            ))
        default:
            return .other
        }
    }

    /// Returns whether to consume the event. Must stay short: macOS delays every key until it returns.
    private func handle(_ input: TapInput) -> Bool {
        switch input {
        case let .tapDisabled(type):
            // macOS disables a tap that answers too slowly or during secure input; keep listening once it allows.
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            Self.log.notice("Media key tap was disabled (type \(type.rawValue, privacy: .public)); re-enabled")
            return false
        case let .mediaKey(event):
            return handleMediaKey(event)
        case .other:
            return false
        }
    }

    private func handleMediaKey(_ event: MediaKeyEvent) -> Bool {
        let keyCode = event.keyCode
        let key: MediaKeyPress.Key
        switch Int32(keyCode) {
        case NX_KEYTYPE_SOUND_UP: key = .volumeUp
        case NX_KEYTYPE_SOUND_DOWN: key = .volumeDown
        case NX_KEYTYPE_MUTE: key = .mute
        default: return false
        }

        guard event.isKeyDown else {
            return consumedKeyCodes.remove(keyCode) != nil
        }
        if event.isRepeat, !key.repeats {
            return consumedKeyCodes.contains(keyCode)
        }

        let flags = event.flags
        // Option alone with a volume key opens Sound settings in macOS; leave that shortcut to the system.
        if flags.contains(.maskAlternate), !flags.contains(.maskShift) {
            consumedKeyCodes.remove(keyCode)
            return false
        }
        let press = MediaKeyPress(key: key, isFine: flags.contains([.maskAlternate, .maskShift]))
        guard let onKeyDown, onKeyDown(press) else {
            consumedKeyCodes.remove(keyCode)
            return false
        }
        consumedKeyCodes.insert(keyCode)
        return true
    }
}
