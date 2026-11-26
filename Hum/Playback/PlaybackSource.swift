import Foundation

enum PlaybackSourceError: Error, Equatable {
    /// AppleScript error -1743: the user hasn't allowed Hum to automate this app.
    case notAuthorized(PlayerApp)
}

/// A music app Hum can read and control.
protocol PlaybackSource: Sendable {
    var id: PlayerApp { get }
    var name: String { get }
    /// True when the app is running. Sources must never launch their app.
    var isRunning: Bool { get }

    /// The current playback, or nil when stopped or not running.
    /// Throws `PlaybackSourceError.notAuthorized` when Automation permission is missing.
    func current() async throws -> PlaybackState?

    /// Raw artwork bytes for the current track, if the app exposes them locally.
    func artworkData() async -> Data?

    func playPause() async
    func nextTrack() async
    func previousTrack() async
    func seek(to position: TimeInterval) async
}
