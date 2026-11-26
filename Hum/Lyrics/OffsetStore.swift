import Foundation
import Observation

/// Per-track lyrics offset in seconds, remembered by `Track.cacheKey`.
///
/// Positive values make lyrics appear earlier (lyric time = playback position + offset).
@Observable
@MainActor
final class OffsetStore {
    static let step: TimeInterval = 0.1
    private static let defaultsKey = "lyricOffsets"

    @ObservationIgnored private let defaults: UserDefaults
    private var offsets: [String: Double]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        offsets = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Double] ?? [:]
    }

    func offset(for track: Track?) -> TimeInterval {
        guard let track else { return 0 }
        return offsets[track.cacheKey] ?? 0
    }

    func adjust(_ track: Track?, by delta: TimeInterval) {
        guard let track else { return }
        set(offset(for: track) + delta, for: track)
    }

    func reset(_ track: Track?) {
        guard let track else { return }
        set(0, for: track)
    }

    private func set(_ value: TimeInterval, for track: Track) {
        // Round to the step so repeated ±0.1 doesn't accumulate float error.
        let rounded = (value / Self.step).rounded() * Self.step
        offsets[track.cacheKey] = abs(rounded) < 0.0001 ? nil : rounded
        defaults.set(offsets, forKey: Self.defaultsKey)
    }
}
