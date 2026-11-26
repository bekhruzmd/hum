import Foundation

struct PlaybackState: Sendable, Equatable {
    let track: Track
    /// Position in seconds at `fetchedAt`.
    let position: TimeInterval
    let isPlaying: Bool
    let fetchedAt: Date
    var isShuffling: Bool? = nil

    /// Estimates the current position between polls: `position + elapsed` while playing.
    func interpolatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return position }
        let estimated = position + max(0, date.timeIntervalSince(fetchedAt))
        return track.duration > 0 ? min(estimated, track.duration) : estimated
    }

    func with(position: TimeInterval? = nil, isPlaying: Bool? = nil, isShuffling: Bool? = nil, fetchedAt: Date = Date()) -> PlaybackState {
        PlaybackState(
            track: track,
            position: position ?? self.position,
            isPlaying: isPlaying ?? self.isPlaying,
            fetchedAt: fetchedAt,
            isShuffling: isShuffling ?? self.isShuffling
        )
    }
}
