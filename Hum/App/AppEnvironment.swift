import AppKit
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
    private(set) lazy var beatGlow = BeatGlowController(environment: self)
    private(set) lazy var desktop = DesktopController(environment: self)
    private(set) lazy var ticker = LyricsTicker(environment: self)
    private(set) lazy var screensaverFeed = ScreensaverFeedWriter(environment: self)
    private(set) lazy var idleScreen = IdleScreenController(environment: self)
    private(set) lazy var hotkeys = HotkeyManager(store: hotkeyStore) { [weak self] action in
        self?.perform(action)
    }

    private var started = false
    private var wasPlaying = false
    private var lastDesktopMode: DesktopMode = .lyrics

    /// Internal (not private) so tests can build an isolated environment.
    init() {}

    /// True when the process is hosting unit tests; surfaces and polling stay off.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Latency compensation (lead offset): compensates for AppleScript polling and audio buffer latency
    /// so lyrics synchronise tightly with vocal onset.
    static let defaultLeadOffset: TimeInterval = 0.35

    /// Lyric time for a playback state at `date`: interpolated position plus the track's offset and lead compensation.
    func lyricTime(_ state: PlaybackState, at date: Date = Date()) -> TimeInterval {
        state.interpolatedPosition(at: date) + offsets.offset(for: state.track) + (Self.isRunningTests ? 0 : Self.defaultLeadOffset)
    }

    /// Seeks so that lyric time `time` is what plays.
    func seek(toLyricTime time: TimeInterval) {
        nowPlaying.seek(to: time - offsets.offset(for: nowPlaying.currentTrack))
    }

    /// Snapshot for the cinematic scene (idle screen, desktop). Reads observable state, so
    /// views calling this re-render when the track, artwork or lyrics change.
    func cinematicData() -> CinematicSceneData {
        let state = nowPlaying.playbackState
        return CinematicSceneData(
            track: state.map { SceneTrackInfo(title: $0.track.title, artist: $0.track.artist, album: $0.track.album, duration: $0.track.duration) },
            artwork: nowPlaying.artworkImage,
            palette: nowPlaying.palette,
            lines: lyrics.timedLines,
            effect: settings.cinematicEffect,
            look: settings.cinematicLook,
            edgeGlow: settings.cinematicEdgeGlow,
            glowAppearance: settings.glowAppearance,
            showsPlayerBar: settings.idlePlayerBar,
            surfaceMaterial: settings.surfaceMaterial,
            displayEdgeProfiles: settings.displayEdgeProfiles,
            isPlaying: state?.isPlaying ?? false,
            isShuffling: state?.isShuffling,
            playbackPosition: { state?.interpolatedPosition(at: $0) ?? 0 },
            lyricTime: { [weak self] date in
                guard let self, let state else { return 0 }
                return self.lyricTime(state, at: date)
            }
        )
    }

    func musicBarActions() -> MusicBarActions {
        MusicBarActions(playPause: { [nowPlaying] in nowPlaying.playPause() },
                        previous: { [nowPlaying] in nowPlaying.previousTrack() },
                        next: { [nowPlaying] in nowPlaying.nextTrack() },
                        seek: { [nowPlaying] in nowPlaying.seek(to: $0) },
                        shuffle: { [nowPlaying] in nowPlaying.toggleShuffle() },
                        openPlayer: { [nowPlaying] in
                            guard let player = nowPlaying.currentTrack?.player else { return }
                            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == player.bundleIdentifier }?
                                .activate(options: [])
                        }, playerName: nowPlaying.currentTrack?.player.displayName ?? "music player")
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
        beatGlow.start()
        desktop.start()
        idleScreen.start()
        hotkeys.start()
        ticker.start()
        screensaverFeed.start()
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
