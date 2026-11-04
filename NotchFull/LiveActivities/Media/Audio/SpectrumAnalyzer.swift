import Accelerate
import Synchronization

/// Turns a mono sample stream into smoothed, normalized frequency bands.
/// Written from the audio queue and read from the UI; all state is behind one lock.
final class SpectrumAnalyzer: Sendable {
    static let bandCount = 16
    private static let fftSize = 1024
    private static let hopSize = 512
    private static let minFrequency = 60.0
    private static let maxFrequency = 14_000.0
    /// Dynamic range mapped onto 0...1 below the running peak.
    private static let dynamicRangeDB: Float = 50

    private struct State {
        var sampleRate = 48_000.0
        var buffer: [Float] = []
        var bands = [Float](repeating: 0, count: SpectrumAnalyzer.bandCount)
        var peakDB: Float = -40
        let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: SpectrumAnalyzer.fftSize, isHalfWindow: false)
        let fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(SpectrumAnalyzer.fftSize))), radix: .radix2, ofType: DSPSplitComplex.self)
    }

    private let state = Mutex(State())

    func reset(sampleRate: Double) {
        state.withLock { state in
            state.sampleRate = sampleRate
            state.buffer.removeAll(keepingCapacity: true)
            state.bands = [Float](repeating: 0, count: Self.bandCount)
        }
    }

    /// Appends interleaved samples, reading only the first channel.
    func append(_ samples: UnsafeBufferPointer<Float>, channelStride: Int) {
        let stride = max(channelStride, 1)
        state.withLock { state in
            for index in Swift.stride(from: 0, to: samples.count, by: stride) {
                state.buffer.append(samples[index])
            }
            while state.buffer.count >= Self.fftSize {
                Self.analyze(&state)
                state.buffer.removeFirst(Self.hopSize)
            }
        }
    }

    /// Current band levels resampled to `count` values in 0...1.
    func levels(count: Int) -> [Float] {
        let bands = state.withLock { $0.bands }
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let start = index * bands.count / count
            let end = max(start + 1, (index + 1) * bands.count / count)
            let slice = bands[start..<end]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }

    private static func analyze(_ state: inout State) {
        guard let fft = state.fft else { return }
        let half = fftSize / 2
        let windowed = vDSP.multiply(state.buffer[0..<fftSize], state.window)

        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBytes { bytes in
                    vDSP_ctoz(bytes.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(half))
                }
                fft.forward(input: split, output: &split)
                vDSP.squareMagnitudes(split, result: &magnitudes)
            }
        }

        let binWidth = state.sampleRate / Double(fftSize)
        let upper = min(maxFrequency, state.sampleRate / 2)
        var bandDB = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            // Log-spaced edges so each band covers a similar musical range.
            let low = minFrequency * pow(upper / minFrequency, Double(band) / Double(bandCount))
            let high = minFrequency * pow(upper / minFrequency, Double(band + 1) / Double(bandCount))
            let lowBin = min(max(Int(low / binWidth), 1), half - 1)
            let highBin = min(max(Int(high / binWidth), lowBin + 1), half)
            let power = magnitudes[lowBin..<highBin].reduce(0, +) / Float(highBin - lowBin)
            bandDB[band] = 10 * log10(power + 1e-12)
        }

        // A slowly decaying peak keeps quiet and loud tracks both using the full height.
        let loudest = bandDB.max() ?? state.peakDB
        state.peakDB = max(loudest, state.peakDB - 0.3)
        let floor = state.peakDB - dynamicRangeDB

        for band in 0..<bandCount {
            let target = ((bandDB[band] - floor) / dynamicRangeDB).clamped(to: 0...1)
            let previous = state.bands[band]
            // Fast attack, slower release.
            let weight: Float = target > previous ? 0.6 : 0.2
            state.bands[band] = previous + (target - previous) * weight
        }
    }
}
