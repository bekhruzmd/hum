import Foundation

enum MusicSource: String, Sendable, Equatable, Hashable {
    case spotify = "Spotify"
    case appleMusic = "Music"

    var bundleIdentifier: String {
        switch self {
        case .spotify:
            return "com.spotify.client"
        case .appleMusic:
            return "com.apple.Music"
        }
    }
}

struct Track: Sendable, Equatable, Hashable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkURL: URL?
    let source: MusicSource

    var cacheKey: String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let roundedDuration = Int(duration.rounded())
        return "\(normalizedTitle)|\(normalizedArtist)|\(roundedDuration)"
    }
}

struct PlaybackState: Sendable, Equatable {
    let track: Track
    let position: TimeInterval
    let isPlaying: Bool
    let fetchedAt: Date

    func interpolatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return position }
        let elapsed = max(0, date.timeIntervalSince(fetchedAt))
        let estimated = position + elapsed
        if track.duration > 0 {
            return min(estimated, track.duration)
        }
        return estimated
    }
}
