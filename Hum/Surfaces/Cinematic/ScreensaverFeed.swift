import Darwin
import Foundation

/// What Hum hands to the Hum screensaver: a snapshot of the current song and its lyrics.
///
/// macOS runs screensavers in the sandboxed `legacyScreenSaver` process, which can't ask
/// Spotify or Music what's playing. Hum writes this JSON (plus the cover) to the user's
/// Application Support folder. The host has read-only access to that location; its own
/// container is deliberately not used for communication.
struct ScreensaverFeed: Codable, Equatable, Sendable {
    static let folderName = "Hum"
    static let fileName = "nowplaying.json"
    static let currentVersion = 1

    /// Foundation remaps the home directory inside the saver host. Resolve the account's
    /// actual home through the password database so both processes open the same file.
    static var realHomeDirectory: URL {
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        let count = max(16_384, Int(sysconf(_SC_GETPW_R_SIZE_MAX)))
        var buffer = [CChar](repeating: 0, count: count)
        return buffer.withUnsafeMutableBufferPointer { storage in
            if getpwuid_r(getuid(), &entry, storage.baseAddress, count, &result) == 0,
               result != nil, let home = entry.pw_dir {
                return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            }
            return FileManager.default.homeDirectoryForCurrentUser
        }
    }

    static func directory(home: URL = realHomeDirectory) -> URL {
        home.appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    var version = ScreensaverFeed.currentVersion
    /// Optional for compatibility with version-one feeds written before sharing status existed.
    var sharingEnabled: Bool?
    var track: SceneTrackInfo?
    /// Lyric time (position + offset) at `anchorDate`.
    var lyricAnchor: TimeInterval = 0
    /// Seconds since 1970 when `lyricAnchor` was true.
    var anchorDate: TimeInterval = 0
    var isPlaying = false
    var playbackAnchor: TimeInterval?
    var isShuffling: Bool?
    var palette: AlbumPalette = .fallback
    var lines: [TimedLine] = []
    var effect: String = LyricEffectKind.constellation.rawValue
    var look: String?
    var edgeGlow: Double?
    var displayEdgeProfiles: [String: DisplayEdgeProfile]?
    /// Optional so older feeds still decode.
    var glowAppearance: GlowAppearance?
    var playerBar: Bool?
    var edgeGlowIntensity: Double { CinematicGlow.clamped(edgeGlow ?? 1) }
    var cinematicLook: CinematicLook { CinematicLook(rawValue: look ?? "") ?? .album }

    /// File name of the cover next to the JSON, if any.
    var artworkFile: String?

    /// A stopped app must not leave a cached song playing forever.
    func isFresh(at date: Date) -> Bool {
        let age = date.timeIntervalSince1970 - anchorDate
        return age >= -5 && age <= 20
    }

    /// Lyric time at `date`, advancing only while playing.
    func lyricTime(at date: Date) -> TimeInterval {
        guard isPlaying else { return lyricAnchor }
        return lyricAnchor + max(0, date.timeIntervalSince1970 - anchorDate)
    }

    /// Separate from lyric time: per-song lyric offsets must never move the player's scrubber.
    func playbackPosition(at date: Date) -> TimeInterval {
        let anchor = playbackAnchor ?? lyricAnchor
        let position = anchor + (isPlaying ? max(0, date.timeIntervalSince1970 - anchorDate) : 0)
        return min(track?.duration ?? .greatestFiniteMagnitude, max(0, position))
    }

    var effectKind: LyricEffectKind {
        LyricEffectKind(rawValue: effect) ?? .constellation
    }
}
