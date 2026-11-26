import Foundation

struct Track: Sendable, Equatable, Hashable {
    let title: String
    let artist: String
    let album: String
    /// Duration in seconds.
    let duration: TimeInterval
    /// Remote artwork URL (Spotify only). Music artwork is fetched as raw data.
    let artworkURL: URL?
    let player: PlayerApp

    /// Key used for lyrics caching and offsets: `title|artist|duration`.
    var cacheKey: String {
        let roundedDuration = Int(duration.rounded())
        return "\(Self.normalize(title))|\(Self.normalize(artist))|\(roundedDuration)"
    }

    /// Key used for artwork and palette caching (one entry per album).
    var albumKey: String {
        let albumPart = album.isEmpty ? title : album
        return "\(Self.normalize(artist))|\(Self.normalize(albumPart))"
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
