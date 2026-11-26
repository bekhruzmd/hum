import Foundation

/// Small deterministic xorshift generator (reproducible sounds and tests).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // splitmix64 scrambles small or similar seeds so early outputs are well spread.
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        state = z == 0 ? 0x9E37_79B9_7F4A_7C15 : z
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
