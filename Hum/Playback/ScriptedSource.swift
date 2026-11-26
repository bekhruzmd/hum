import AppKit
import Foundation

/// Shared AppleScript plumbing for Spotify and Music, which use the same verbs.
///
/// Every script is wrapped in `if application id "…" is running`, so a player that quits
/// between our `NSWorkspace` check and script execution is never relaunched.
protocol ScriptedSource: PlaybackSource {
    var runner: AppleScriptRunner { get }
    /// The body of the read script. It must `return` a field-joined string or "STOPPED".
    var readScriptBody: String { get }
}

extension ScriptedSource {
    var name: String { id.displayName }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == id.bundleIdentifier }
    }

    func current() async throws -> PlaybackState? {
        guard isRunning else { return nil }
        do {
            let raw = try await runner.string(guarded(readScriptBody))
            return PlaybackParser.parse(raw, player: id)
        } catch AppleScriptRunner.RunError.notAuthorized {
            throw PlaybackSourceError.notAuthorized(id)
        } catch {
            return nil
        }
    }

    func playPause() async { await command("playpause") }
    func nextTrack() async { await command("next track") }
    func previousTrack() async { await command("previous track") }

    func seek(to position: TimeInterval) async {
        let seconds = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(0, position))
        await command("set player position to \(seconds)")
    }

    func command(_ verb: String) async {
        guard isRunning else { return }
        _ = try? await runner.execute(guarded(verb))
    }

    func guarded(_ body: String) -> String {
        """
        if application id "\(id.bundleIdentifier)" is running then
            tell application id "\(id.bundleIdentifier)"
                \(body)
            end tell
        end if
        """
    }
}
