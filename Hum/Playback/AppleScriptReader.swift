import AppKit
import Foundation

enum AppleScriptPlaybackResult: Sendable {
    case playing(PlaybackState)
    case nothingPlaying
    case notAuthorized(MusicSource)
}

enum AppleScriptReader {
    private static let fieldSeparator = "\u{001F}"
    private static let notAuthorizedErrorCode = -1743

    private static let spotifyScript: NSAppleScript? = NSAppleScript(source: """
    tell application "Spotify"
        set pState to player state as string
        if pState is "stopped" then
            return "STOPPED"
        end if
        set tName to name of current track
        set tArtist to artist of current track
        set tAlbum to album of current track
        set tDuration to duration of current track
        set tPos to player position
        set tArt to artwork url of current track
        set sep to ASCII character 31
        return pState & sep & tName & sep & tArtist & sep & tAlbum & sep & tDuration & sep & tPos & sep & tArt
    end tell
    """)

    private static let musicScript: NSAppleScript? = NSAppleScript(source: """
    tell application "Music"
        set pState to player state as string
        if pState is "stopped" then
            return "STOPPED"
        end if
        set tName to name of current track
        set tArtist to artist of current track
        set tAlbum to album of current track
        set tDuration to duration of current track
        set tPos to player position
        set sep to ASCII character 31
        return pState & sep & tName & sep & tArtist & sep & tAlbum & sep & tDuration & sep & tPos
    end tell
    """)

    static func fetchActivePlayback() -> AppleScriptPlaybackResult {
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )

        let spotifyRunning = runningBundleIDs.contains(MusicSource.spotify.bundleIdentifier)
        let musicRunning = runningBundleIDs.contains(MusicSource.appleMusic.bundleIdentifier)

        var candidates: [PlaybackState] = []
        var unauthorizedSource: MusicSource?

        if spotifyRunning {
            switch query(.spotify) {
            case .playing(let state):
                if state.isPlaying { return .playing(state) }
                candidates.append(state)
            case .notAuthorized(let source):
                unauthorizedSource = unauthorizedSource ?? source
            case .nothingPlaying:
                break
            }
        }

        if musicRunning {
            switch query(.appleMusic) {
            case .playing(let state):
                if state.isPlaying { return .playing(state) }
                candidates.append(state)
            case .notAuthorized(let source):
                unauthorizedSource = unauthorizedSource ?? source
            case .nothingPlaying:
                break
            }
        }

        if let firstPaused = candidates.first {
            return .playing(firstPaused)
        }

        if let unauthorizedSource {
            return .notAuthorized(unauthorizedSource)
        }

        return .nothingPlaying
    }

    private static func query(_ source: MusicSource) -> AppleScriptPlaybackResult {
        let script = (source == .spotify) ? spotifyScript : musicScript
        guard let script else { return .nothingPlaying }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            if let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int,
               errorNumber == notAuthorizedErrorCode {
                return .notAuthorized(source)
            }
            return .nothingPlaying
        }

        guard let raw = descriptor.stringValue, !raw.isEmpty, raw != "STOPPED" else {
            return .nothingPlaying
        }

        return parse(raw: raw, source: source)
    }

    private static func parse(raw: String, source: MusicSource) -> AppleScriptPlaybackResult {
        let fields = raw.components(separatedBy: fieldSeparator)
        guard fields.count >= 6 else { return .nothingPlaying }

        let stateString = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let album = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return .nothingPlaying }

        let rawDuration = parseLocaleDouble(fields[4]) ?? 0
        let durationSeconds = (source == .spotify) ? (rawDuration / 1000.0) : rawDuration
        let positionSeconds = parseLocaleDouble(fields[5]) ?? 0
        let artworkURL: URL? = (fields.count >= 7)
            ? URL(string: fields[6].trimmingCharacters(in: .whitespacesAndNewlines))
            : nil

        let isPlaying = (stateString == "playing")
        let track = Track(
            title: title,
            artist: artist,
            album: album,
            duration: max(0, durationSeconds),
            artworkURL: artworkURL,
            source: source
        )
        let playbackState = PlaybackState(
            track: track,
            position: max(0, positionSeconds),
            isPlaying: isPlaying,
            fetchedAt: Date()
        )
        return .playing(playbackState)
    }

    private static func parseLocaleDouble(_ string: String) -> Double? {
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}
