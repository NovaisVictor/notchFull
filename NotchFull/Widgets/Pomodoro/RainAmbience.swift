import AVFoundation
import Observation

/// Synthesized rain: low rumble (brown noise), a soft hiss and random droplets.
/// Generated in real time, so the app ships no audio file and carries no licensing question.
@MainActor
@Observable
final class RainAmbience {
    private(set) var isPlaying = false
    private(set) var lastError: String?

    private static let volume: Float = 0.35
    private static let fadeSteps = 20
    private static let fadeDuration: Duration = .milliseconds(800)

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var source: AVAudioSourceNode?
    @ObservationIgnored private var fade: Task<Void, Never>?

    func setPlaying(_ shouldPlay: Bool) {
        guard shouldPlay != isPlaying else { return }
        shouldPlay ? start() : stop()
    }

    private func start() {
        do {
            if source == nil {
                try configureEngine()
            }
            engine.mainMixerNode.outputVolume = 0
            try engine.start()
            isPlaying = true
            lastError = nil
            fadeVolume(to: Self.volume) {}
        } catch {
            lastError = "Rain could not start: \(error.localizedDescription)"
        }
    }

    private func stop() {
        isPlaying = false
        fadeVolume(to: 0) { [weak self] in
            self?.engine.stop()
        }
    }

    private func configureEngine() throws {
        let format = engine.outputNode.inputFormat(forBus: 0)
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1) else {
            throw RainError.unsupportedFormat
        }
        let node = AVAudioSourceNode(format: mono, renderBlock: Self.makeRenderBlock(generator: RainGenerator()))

        // Rain lives below ~6 kHz; cutting the top keeps the hiss from sounding like static.
        let filter = AVAudioUnitEQ(numberOfBands: 1)
        filter.bands[0].filterType = .lowPass
        filter.bands[0].frequency = 6000
        filter.bands[0].bypass = false

        engine.attach(node)
        engine.attach(filter)
        engine.connect(node, to: filter, format: mono)
        engine.connect(filter, to: engine.mainMixerNode, format: mono)
        source = node
    }

    private func fadeVolume(to target: Float, completion: @escaping @MainActor () -> Void) {
        fade?.cancel()
        let start = engine.mainMixerNode.outputVolume
        fade = Task { [weak self] in
            for step in 1...Self.fadeSteps {
                do {
                    try await Task.sleep(for: Self.fadeDuration / Self.fadeSteps)
                } catch {
                    // A newer fade took over.
                    return
                }
                let progress = Float(step) / Float(Self.fadeSteps)
                self?.engine.mainMixerNode.outputVolume = start + (target - start) * progress
            }
            completion()
        }
    }

    // Built outside the main actor: Core Audio calls it on its real-time render thread.
    nonisolated private static func makeRenderBlock(generator: RainGenerator) -> AVAudioSourceNodeRenderBlock {
        { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            for frame in 0..<Int(frameCount) {
                data[frame] = generator.nextSample()
            }
            return noErr
        }
    }

    private enum RainError: LocalizedError {
        case unsupportedFormat

        var errorDescription: String? {
            "The audio output format is not supported."
        }
    }
}

/// Per-sample noise state. Only the render thread touches it after creation, hence the unchecked conformance.
private final class RainGenerator: @unchecked Sendable {
    private var brown: Float = 0
    private var droplet: Float = 0
    private var seed: UInt32 = 0x9E37_79B9

    func nextSample() -> Float {
        let white = nextWhite()
        // Integrated white noise (brown) is the low rumble of rain on a surface.
        brown = (brown + 0.02 * white) / 1.02
        // Occasional short bursts read as individual drops.
        if nextUnit() < 0.0006 {
            droplet = 0.6 + 0.4 * nextUnit()
        }
        droplet *= 0.992
        return brown * 3.2 + white * 0.04 + white * droplet * 0.25
    }

    /// xorshift32: allocation-free and real-time safe, unlike the system random generator.
    private func nextUnit() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max)
    }

    private func nextWhite() -> Float {
        nextUnit() * 2 - 1
    }
}
