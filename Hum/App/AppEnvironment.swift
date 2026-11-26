import Foundation

/// Owns the app-wide stores and wires them together. Created once at launch.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings = SettingsStore()
    let nowPlaying = NowPlayingStore()
    let lyrics = LyricsStore()
    private(set) lazy var windows = WindowManager(environment: self)

    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        nowPlaying.onTrackChange = { [lyrics] track in
            lyrics.update(for: track)
        }
        observeContinuously(self) { env in
            env.nowPlaying.preferredPlayer = env.settings.preferredPlayer
        }
        nowPlaying.start()
    }
}
