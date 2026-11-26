import Foundation

/// Owns the app-wide stores and wires them together. Created once at launch.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings = SettingsStore()
    let nowPlaying = NowPlayingStore()
    let lyrics = LyricsStore()
    let offsets = OffsetStore()
    let renderGate = RenderGate()
    let hotkeyStore = HotkeyStore()
    let sounds = SoundEngine()
    private(set) lazy var windows = WindowManager(environment: self)
    private(set) lazy var island = IslandController(environment: self)
    private(set) lazy var desktop = DesktopController(environment: self)
    private(set) lazy var ticker = LyricsTicker(environment: self)
    private(set) lazy var idleScreen = IdleScreenController(environment: self)
    private(set) lazy var hotkeys = HotkeyManager(store: hotkeyStore) { [weak self] action in
        self?.perform(action)
    }

    private var started = false
    private var wasPlaying = false
    private var lastDesktopMode: DesktopMode = .turntable

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

    /// Snapshot for the cinematic scene (idle screen, desktop). Reads observable state, so
    /// views calling this re-render when the track, artwork or lyrics change.
    func cinematicData() -> CinematicSceneData {
        let state = nowPlaying.playbackState
        let offset = offsets.offset(for: state?.track)
        return CinematicSceneData(
            track: state.map { SceneTrackInfo(title: $0.track.title, artist: $0.track.artist, album: $0.track.album) },
            artwork: nowPlaying.artworkImage,
            palette: nowPlaying.palette,
            lines: lyrics.timedLines,
            effect: settings.cinematicEffect,
            isPlaying: state?.isPlaying ?? false,
            lyricTime: { date in (state?.interpolatedPosition(at: date) ?? 0) + offset }
        )
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
        renderGate.start()
        nowPlaying.start()
        island.start()
        desktop.start()
        idleScreen.start()
        hotkeys.start()
        ticker.start()
        observeContinuously(self) { env in env.updateSounds() }
    }

    func perform(_ action: HotkeyAction) {
        switch action {
        case .playPause: nowPlaying.playPause()
        case .nextTrack: nowPlaying.nextTrack()
        case .previousTrack: nowPlaying.previousTrack()
        case .showLyrics: windows.toggleLyrics()
        case .toggleDesktop: toggleDesktop()
        case .idleScreen: idleScreen.isShowing ? idleScreen.dismiss() : idleScreen.show()
        case .offsetEarlier: nudgeOffset(by: OffsetStore.step)
        case .offsetLater: nudgeOffset(by: -OffsetStore.step)
        }
    }

    private func toggleDesktop() {
        if settings.desktopMode == .off {
            settings.desktopMode = lastDesktopMode
        } else {
            lastDesktopMode = settings.desktopMode
            settings.desktopMode = .off
        }
    }

    /// Needle drop when playback starts; crackle loops only while playing.
    private func updateSounds() {
        let playing = nowPlaying.isPlaying
        let volume = Float(settings.soundVolume)
        if playing && !wasPlaying && settings.needleDropSound {
            sounds.playNeedleDrop(volume: volume)
        }
        wasPlaying = playing
        sounds.setCrackle(enabled: playing && settings.crackleSound, volume: volume * 0.5)
    }
}
