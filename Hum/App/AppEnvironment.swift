import Foundation

/// Owns the app-wide stores and wires them together. Created once at launch.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings = SettingsStore()
    let nowPlaying = NowPlayingStore()
    let lyrics = LyricsStore()
    let offsets = OffsetStore()
    private(set) lazy var windows = WindowManager(environment: self)
    private(set) lazy var island = IslandController(environment: self)

    private var started = false

    /// Internal (not private) so tests can build an isolated environment.
    init() {}

    /// True when the process is hosting unit tests; surfaces and polling stay off.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Lyric time for a playback state at `date`: interpolated position plus the track's offset.
    func lyricTime(_ state: PlaybackState, at date: Date = Date()) -> TimeInterval {
        state.interpolatedPosition(at: date) + offsets.offset(for: state.track)
    }

    /// Seeks so that lyric time `time` is what plays.
    func seek(toLyricTime time: TimeInterval) {
        nowPlaying.seek(to: time - offsets.offset(for: nowPlaying.currentTrack))
    }

    func nudgeOffset(by delta: TimeInterval) {
        offsets.adjust(nowPlaying.currentTrack, by: delta)
    }

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
        island.start()
    }
}
