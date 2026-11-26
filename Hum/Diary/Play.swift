import Foundation
import SwiftData

/// A single logged play. Recorded after a track has played for 30 s or 50% of its duration,
/// whichever comes first. Never sent anywhere: everything stays on-device.
@Model
final class Play {
    /// The title of the track.
    var title: String
    /// The artist of the track.
    var artist: String
    /// The album of the track.
    var album: String
    /// Which player was used (Spotify / Music).
    var source: String
    /// When the user started listening.
    var startedAt: Date
    /// How many seconds the user actually listened.
    var secondsListened: TimeInterval

    init(title: String, artist: String, album: String, source: String, startedAt: Date, secondsListened: TimeInterval) {
        self.title = title
        self.artist = artist
        self.album = album
        self.source = source
        self.startedAt = startedAt
        self.secondsListened = secondsListened
    }
}
