import Foundation

struct SpotifySource: ScriptedSource {
    let id: PlayerApp = .spotify
    let runner: AppleScriptRunner

    init(runner: AppleScriptRunner = .shared) {
        self.runner = runner
    }

    let readScriptBody = """
    set pState to player state as string
    if pState is "stopped" then return "STOPPED"
    set t to current track
    set sep to ASCII character 31
    return pState & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (duration of t) & sep & player position & sep & (artwork url of t)
    """

    /// Spotify exposes artwork as a URL, loaded by `ArtworkLoader`.
    func artworkData() async -> Data? { nil }
}
