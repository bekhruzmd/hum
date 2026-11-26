import Foundation

/// Hum's sounds are synthesized in code, so they are original by construction (no samples).
///
/// - `needleDrop`: a soft low thump as the stylus lands, a tiny contact click, and a few
///   groove crackles fading out.
/// - `CrackleGenerator`: endless faint vinyl surface noise: filtered hiss with sparse pops.
enum SoundSynth {
    static let sampleRate: Double = 44_100

    static func needleDrop(sampleRate: Double = sampleRate, seed: UInt64 = 0x5EED) -> [Float] {
        var rng = SeededRandom(seed: seed)
        let count = Int(sampleRate * 0.9)
        var output = [Float](repeating: 0, count: count)
        var phase = 0.0
        var lowpass: Float = 0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Thump: pitch falls 95 → 45 Hz with a fast decay.
            let frequency = 45 + 50 * exp(-t * 14)
            phase += 2 * .pi * frequency / sampleRate
            let thump = sin(phase) * exp(-t * 16) * 0.55

            // Contact click: 3 ms of decaying noise.
            let click = t < 0.003 ? Double(rng.nextSigned()) * (1 - t / 0.003) * 0.35 : 0

            // Groove rumble: low-passed noise swelling in after the drop, then fading.
            let swell = t < 0.12 ? 0 : min(1, (t - 0.12) / 0.15) * exp(-(t - 0.12) * 4)
            lowpass += 0.08 * (rng.nextSigned() - lowpass)
            let rumble = Double(lowpass) * swell * 0.18

            output[i] = Float(thump + click + rumble)
        }

        // A handful of crackles in the tail.
        for _ in 0..<7 {
            let start = Int(sampleRate * Double(rng.next(in: 0.15...0.8)))
            let amplitude = rng.next(in: 0.05...0.18)
            addPop(to: &output, at: start, amplitude: amplitude, decaySamples: rng.next(in: 30...120), rng: &rng)
        }
        return softClip(output)
    }

    static func addPop(to buffer: inout [Float], at start: Int, amplitude: Float, decaySamples: Float, rng: inout SeededRandom) {
        let length = Int(decaySamples * 5)
        for j in 0..<length where start + j < buffer.count {
            let envelope = amplitude * exp(-Float(j) / decaySamples)
            buffer[start + j] += envelope * rng.nextSigned()
        }
    }

    static func softClip(_ samples: [Float]) -> [Float] {
        samples.map { tanh($0 * 1.2) / tanh(1.2) * 0.9 }
    }
}

/// Streaming vinyl crackle. Not thread-safe: own one per render thread.
///
/// Warm, dark surface noise: low-passed hiss plus dense tiny pops and occasional bigger
/// ones, each pop low-passed so it sounds like dust in a groove rather than a click.
struct CrackleGenerator {
    private var rng: SeededRandom
    private var hissState: Float = 0
    private var hissState2: Float = 0
    private var popLevel: Float = 0
    private var popDecay: Float = 0.99
    private var popFilter: Float = 0
    private var popCutoff: Float = 0.3
    let sampleRate: Float

    /// Average pops per second (most are tiny).
    var popRate: Float = 18

    init(sampleRate: Double = SoundSynth.sampleRate, seed: UInt64 = 0xC4AC) {
        self.sampleRate = Float(sampleRate)
        rng = SeededRandom(seed: seed)
    }

    mutating func next() -> Float {
        // Hiss: white noise through two one-pole low-passes (dark, soft).
        hissState += 0.12 * (rng.nextSigned() - hissState)
        hissState2 += 0.12 * (hissState - hissState2)
        let hiss = hissState2 * 0.03

        if rng.nextUnit() < popRate / sampleRate {
            // Mostly small dust specks, sometimes a louder pop.
            let big = rng.nextUnit() < 0.12
            popLevel = big ? rng.next(in: 0.12...0.28) : rng.next(in: 0.015...0.07)
            popDecay = exp(-1 / rng.next(in: big ? 40...120 : 8...30))
            popCutoff = rng.next(in: 0.15...0.45)
        }
        let raw = popLevel * rng.nextSigned()
        popLevel *= popDecay
        popFilter += popCutoff * (raw - popFilter)
        return hiss + popFilter * 1.6
    }
}

/// Small deterministic xorshift generator (reproducible sounds and tests).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextUInt() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// 0..<1
    mutating func nextUnit() -> Float {
        Float(nextUInt() >> 40) / Float(1 << 24)
    }

    /// -1..<1
    mutating func nextSigned() -> Float {
        nextUnit() * 2 - 1
    }

    mutating func next(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }
}
