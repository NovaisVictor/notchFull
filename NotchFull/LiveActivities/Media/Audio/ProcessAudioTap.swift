import AudioToolbox
import CoreAudio
import Foundation

enum AudioTapError: LocalizedError {
    case processHasNoAudio(pid_t)
    case coreAudio(operation: String, status: OSStatus)
    case cleanupFailed([String])
    case startFailed(cause: String, cleanupFailures: [String])

    var errorDescription: String? {
        switch self {
        case let .processHasNoAudio(pid):
            "Process \(pid) has not produced audio yet."
        case let .coreAudio(operation, status):
            "Could not \(operation) (OSStatus \(status))."
        case let .cleanupFailed(failures):
            "Audio capture cleanup failed: " + failures.joined(separator: "; ")
        case let .startFailed(cause, cleanupFailures):
            cause + " Cleanup also failed: " + cleanupFailures.joined(separator: "; ")
        }
    }
}

/// Captures one process's audio output through a Core Audio process tap (macOS 14.2+) and feeds the analyzer.
/// The tap is private and unmuted: the user keeps hearing the audio normally.
@MainActor
final class ProcessAudioTap {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var isRunning = false
    private let ioQueue = DispatchQueue(label: "com.victornovais.NotchFull.audio-tap", qos: .userInteractive)

    init(pid: pid_t, analyzer: SpectrumAnalyzer) throws {
        do {
            try start(pid: pid, analyzer: analyzer)
        } catch {
            let cleanupFailures = tearDown()
            guard cleanupFailures.isEmpty else {
                throw AudioTapError.startFailed(cause: error.localizedDescription, cleanupFailures: cleanupFailures)
            }
            throw error
        }
    }

    /// Releases every Core Audio object; resources that fail to release are kept so a later call can retry.
    func stop() throws {
        let failures = tearDown()
        if !failures.isEmpty {
            throw AudioTapError.cleanupFailed(failures)
        }
    }

    private func start(pid: pid_t, analyzer: SpectrumAnalyzer) throws {
        let processObject = try Self.processObject(for: pid)

        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var tap = AudioObjectID(kAudioObjectUnknown)
        try Self.check("create the process tap", AudioHardwareCreateProcessTap(description, &tap))
        tapID = tap

        let format = try Self.tapFormat(tap)
        let outputUID = try Self.defaultOutputDeviceUID()
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "NotchFull Visualizer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]

        var aggregate = AudioObjectID(kAudioObjectUnknown)
        try Self.check("create the aggregate device", AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregate))
        aggregateDeviceID = aggregate

        analyzer.reset(sampleRate: format.mSampleRate)

        var procID: AudioDeviceIOProcID?
        try Self.check(
            "create the audio callback",
            AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate, ioQueue, Self.makeIOBlock(analyzer: analyzer))
        )
        ioProcID = procID

        try Self.check("start audio capture", AudioDeviceStart(aggregate, procID))
        isRunning = true
    }

    private func tearDown() -> [String] {
        var failures: [String] = []

        func record(_ operation: String, _ status: OSStatus) -> Bool {
            guard status != noErr else { return true }
            failures.append("\(operation) (OSStatus \(status))")
            return false
        }

        if aggregateDeviceID != kAudioObjectUnknown {
            if let procID = ioProcID {
                if isRunning, record("stop audio capture", AudioDeviceStop(aggregateDeviceID, procID)) {
                    isRunning = false
                }
                if !isRunning, record("destroy the audio callback", AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)) {
                    ioProcID = nil
                }
            }
            if ioProcID == nil, record("destroy the aggregate device", AudioHardwareDestroyAggregateDevice(aggregateDeviceID)) {
                aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            }
        }
        if aggregateDeviceID == kAudioObjectUnknown, tapID != kAudioObjectUnknown,
           record("destroy the process tap", AudioHardwareDestroyProcessTap(tapID)) {
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        return failures
    }

    // Built outside the main actor: Core Audio calls the block on `ioQueue`, never on the main thread.
    nonisolated private static func makeIOBlock(analyzer: SpectrumAnalyzer) -> AudioDeviceIOBlock {
        { _, inputData, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count)
                analyzer.append(samples, channelStride: Int(buffer.mNumberChannels))
            }
        }
    }

    nonisolated private static func check(_ operation: String, _ status: OSStatus) throws {
        guard status == noErr else {
            throw AudioTapError.coreAudio(operation: operation, status: status)
        }
    }

    nonisolated private static func processObject(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            "find the player's audio process",
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        )
        guard object != kAudioObjectUnknown else {
            throw AudioTapError.processHasNoAudio(pid)
        }
        return object
    }

    nonisolated private static func tapFormat(_ tap: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check("read the tap format", AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format))
        return format
    }

    nonisolated private static func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check("find the output device", AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device))

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check("read the output device ID", AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid))
        guard let uid else {
            throw AudioTapError.coreAudio(operation: "read the output device ID", status: kAudioHardwareUnspecifiedError)
        }
        return uid.takeRetainedValue() as String
    }
}
