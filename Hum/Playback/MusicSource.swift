import Foundation

struct MusicSource: ScriptedSource {
    let id: PlayerApp = .appleMusic
    let runner: AppleScriptRunner

    init(runner: AppleScriptRunner = .shared) {
        self.runner = runner
    }

    let readScriptBody = """
    set pState to player state as string
    if pState is "stopped" then return "STOPPED"
    set t to current track
    set sep to ASCII character 31
    return pState & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (duration of t) & sep & player position
    """

    private let artworkScriptBody = """
    if (count of artworks of current track) > 0 then
        return raw data of artwork 1 of current track
    end if
    return ""
    """

    func artworkData() async -> Data? {
        guard isRunning, let data = try? await runner.data(guarded(artworkScriptBody)) else { return nil }
        // An empty-string reply decodes to a few bytes of text, not an image.
        return data.count > 64 ? data : nil
    }
}
