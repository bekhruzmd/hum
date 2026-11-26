import Foundation
import Observation

/// Publishes the current lyric line for the menu bar.
///
/// Event-driven: after each update it sleeps until the next line starts (capped at 1 s so
/// seeks and pauses are picked up), rather than ticking at a fixed frame rate.
@Observable
@MainActor
final class LyricsTicker {
    private(set) var line: String?

    @ObservationIgnored private unowned let environment: AppEnvironment
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Menu bar text is clipped to this many characters.
    static let maxLength = 48

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        observeContinuously(self) { ticker in
            ticker.setRunning(ticker.environment.settings.menuBarLyrics)
        }
    }

    private func setRunning(_ running: Bool) {
        guard running != (task != nil) else { return }
        task?.cancel()
        task = nil
        line = nil
        guard running else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                let wait = self?.update() ?? 1
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    /// Updates `line` and returns how long to sleep.
    private func update() -> TimeInterval {
        guard let state = environment.nowPlaying.playbackState, state.isPlaying else {
            if line != nil { line = nil }
            return 1
        }
        let lines = environment.lyrics.timedLines
        let time = environment.lyricTime(state)
        let index = lines.activeIndex(at: time)
        let text = index.map { lines[$0].text }.flatMap { $0.isEmpty ? nil : Self.clip($0) }
        if text != line { line = text }

        let nextIndex = (index ?? -1) + 1
        guard nextIndex < lines.count else { return 1 }
        return min(1, max(0.05, lines[nextIndex].start - time))
    }

    static func clip(_ text: String) -> String {
        text.count <= maxLength ? text : String(text.prefix(maxLength - 1)) + "…"
    }
}
