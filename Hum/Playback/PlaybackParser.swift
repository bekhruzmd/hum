import Foundation

/// Parses the field-joined string returned by the player scripts.
///
/// Fields: state, title, artist, album, duration, position, [artwork url].
/// Joined by ASCII 31 (unit separator) so titles containing commas, tabs or pipes survive.
enum PlaybackParser {
    static let fieldSeparator = "\u{001F}"
    static let stoppedMarker = "STOPPED"

    static func parse(_ raw: String, player: PlayerApp, now: Date = Date()) -> PlaybackState? {
        guard !raw.isEmpty, raw != stoppedMarker else { return nil }
        let fields = raw.components(separatedBy: fieldSeparator)
        guard fields.count >= 6 else { return nil }

        let title = trimmed(fields[1])
        guard !title.isEmpty else { return nil }

        let rawDuration = parseDouble(fields[4]) ?? 0
        // Spotify reports duration in milliseconds; Music in seconds.
        let duration = player == .spotify ? rawDuration / 1000.0 : rawDuration
        let artworkURL = fields.count >= 7 ? URL(string: trimmed(fields[6])) : nil

        let track = Track(
            title: title,
            artist: trimmed(fields[2]),
            album: trimmed(fields[3]),
            duration: max(0, duration),
            artworkURL: artworkURL?.scheme == "https" ? artworkURL : nil,
            player: player
        )
        return PlaybackState(
            track: track,
            position: max(0, parseDouble(fields[5]) ?? 0),
            isPlaying: trimmed(fields[0]).lowercased() == "playing",
            fetchedAt: now
        )
    }

    /// Parses a number that may use "," as its decimal separator (locale-dependent AppleScript output).
    static func parseDouble(_ string: String) -> Double? {
        Double(trimmed(string).replacingOccurrences(of: ",", with: "."))
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
