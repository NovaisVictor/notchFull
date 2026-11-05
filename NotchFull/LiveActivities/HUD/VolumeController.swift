import AudioToolbox
import CoreAudio
import Foundation

enum VolumeControlError: LocalizedError {
    case coreAudio(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case let .coreAudio(operation, status):
            "Could not \(operation) (OSStatus \(status))."
        }
    }
}

/// Reads and changes the default output device's volume with public Core Audio properties.
/// Every call is short and synchronous because the key tap must decide right away whether to consume a key.
enum VolumeController {
    enum Change {
        /// Moves the level by one step of `1 / steps`, snapping to that grid like the system does.
        case step(up: Bool, steps: Int)
        case toggleMute
    }

    enum Outcome {
        case applied(HUDState)
        /// The device cannot do this change through Core Audio, so the key must go to macOS untouched.
        case unsupported(reason: String)
    }

    static func apply(_ change: Change) throws -> Outcome {
        let device = try defaultOutputDevice()
        let deviceName = try outputName(device)
        let displayedName = deviceName ?? "The built-in output"

        guard try isSettable(device, volumeAddress) else {
            return .unsupported(reason: "\(displayedName) has no volume that apps can change, so its volume keys go to macOS.")
        }
        let hasMute = hasProperty(device, muteAddress)
        let canSetMute = try hasMute && isSettable(device, muteAddress)

        var level = try Double(read(device, volumeAddress, as: Float32.self, operation: "read the output volume"))
        var isMuted = try hasMute && read(device, muteAddress, as: UInt32.self, operation: "read the mute state") != 0

        switch change {
        case let .step(up, steps):
            let grid = Double(steps)
            let index = (level * grid).rounded() + (up ? 1 : -1)
            level = (index / grid).clamped(to: 0...1)
            try write(device, volumeAddress, Float32(level), operation: "change the output volume")
            // Raising the volume of a muted output means the user wants to hear it again, as in macOS.
            if up, isMuted, canSetMute {
                try write(device, muteAddress, UInt32(0), operation: "unmute the output")
                isMuted = false
            }
        case .toggleMute:
            guard canSetMute else {
                return .unsupported(reason: "\(displayedName) cannot be muted by apps, so its mute key goes to macOS.")
            }
            isMuted.toggle()
            try write(device, muteAddress, UInt32(isMuted ? 1 : 0), operation: isMuted ? "mute the output" : "unmute the output")
        }
        return .applied(.volume(level: level, isMuted: isMuted, deviceName: deviceName))
    }

    // The volume keys act on the default output (where apps play), not on the alerts device.
    private static func defaultOutputDevice() throws -> AudioObjectID {
        let address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let device = try read(AudioObjectID(kAudioObjectSystemObject), address, as: AudioObjectID.self, operation: "find the output device")
        guard device != kAudioObjectUnknown else {
            throw VolumeControlError.coreAudio(operation: "find the output device", status: kAudioHardwareBadDeviceError)
        }
        return device
    }

    /// Device name for the HUD, or `nil` for built-in outputs (speakers, headphone jack), which the HUD calls "Volume".
    private static func outputName(_ device: AudioObjectID) throws -> String? {
        let transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let transport = try read(device, transportAddress, as: UInt32.self, operation: "read the output device type")
        guard transport != kAudioDeviceTransportTypeBuiltIn else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check("read the output device name", AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &size, &name))
        guard let name else {
            throw VolumeControlError.coreAudio(operation: "read the output device name", status: kAudioHardwareUnspecifiedError)
        }
        return name.takeRetainedValue() as String
    }

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    /// `false` when the device lacks the property (for example HDMI outputs or DACs with fixed volume).
    private static func isSettable(_ device: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> Bool {
        guard hasProperty(device, address) else { return false }
        var address = address
        var settable: DarwinBoolean = false
        try check("check whether the output can be changed", AudioObjectIsPropertySettable(device, &address, &settable))
        return settable.boolValue
    }

    private static func hasProperty(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(object, &address)
    }

    private static func read<Value: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, as type: Value.Type, operation: String) throws -> Value {
        var address = address
        var size = UInt32(MemoryLayout<Value>.size)
        let value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { value.deallocate() }
        try check(operation, AudioObjectGetPropertyData(object, &address, 0, nil, &size, value))
        return value.pointee
    }

    private static func write<Value: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: Value, operation: String) throws {
        var address = address
        var value = value
        try check(operation, AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value))
    }

    private static func check(_ operation: String, _ status: OSStatus) throws {
        guard status == noErr else {
            throw VolumeControlError.coreAudio(operation: operation, status: status)
        }
    }
}
