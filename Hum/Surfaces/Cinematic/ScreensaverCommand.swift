import Foundation

/// Lightweight IPC between the screensaver and the Hum app. The saver writes a command file
/// into the shared Application Support folder; the app polls it at the same cadence as the
/// feed heartbeat and executes the command, then deletes the file.
///
/// Commands are intentionally one-shot and tiny (< 100 bytes). The file is written atomically
/// so a partial read is impossible. If Hum isn't running, the commands are silently ignored
/// and expire on the next launch.
struct ScreensaverCommand: Codable, Equatable, Sendable {
    static let fileName = "command.json"

    enum Action: String, Codable, Sendable {
        case playPause
        case next
        case previous
        case shuffle
        case seek
    }

    var action: Action
    /// For `.seek`: the target position in seconds.
    var seekPosition: TimeInterval?

    // MARK: Write (screensaver side)

    static func send(_ action: Action, seekPosition: TimeInterval? = nil) {
        let command = ScreensaverCommand(action: action, seekPosition: seekPosition)
        guard let data = try? JSONEncoder().encode(command) else { return }
        let file = ScreensaverFeed.directory().appendingPathComponent(fileName)
        try? data.write(to: file, options: .atomic)
    }

    // MARK: Read & consume (app side)

    static func consume() -> ScreensaverCommand? {
        let file = ScreensaverFeed.directory().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: file),
              let command = try? JSONDecoder().decode(ScreensaverCommand.self, from: data)
        else { return nil }
        try? FileManager.default.removeItem(at: file)
        return command
    }
}
