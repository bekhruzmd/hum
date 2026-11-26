import Foundation

/// What Hum hands to the Hum screensaver: a snapshot of the current song and its lyrics.
///
/// macOS runs screensavers in the sandboxed `legacyScreenSaver` process, which can't ask
/// Spotify or Music what's playing. Hum writes this JSON (plus the cover) into that
/// process's own Application Support folder, where the screensaver can read it.
struct ScreensaverFeed: Codable, Equatable, Sendable {
    static let folderName = "Hum"
    static let fileName = "nowplaying.json"
    static let currentVersion = 1

    var version = ScreensaverFeed.currentVersion
    var track: SceneTrackInfo?
    /// Lyric time (position + offset) at `anchorDate`.
    var lyricAnchor: TimeInterval = 0
    /// Seconds since 1970 when `lyricAnchor` was true.
    var anchorDate: TimeInterval = 0
    var isPlaying = false
    var palette: AlbumPalette = .fallback
    var lines: [TimedLine] = []
    var effect: String = LyricEffectKind.constellation.rawValue
    /// File name of the cover next to the JSON, if any.
    var artworkFile: String?

    /// Lyric time at `date`, advancing only while playing.
    func lyricTime(at date: Date) -> TimeInterval {
        guard isPlaying else { return lyricAnchor }
        return lyricAnchor + max(0, date.timeIntervalSince1970 - anchorDate)
    }

    var effectKind: LyricEffectKind {
        LyricEffectKind(rawValue: effect) ?? .constellation
    }
}
