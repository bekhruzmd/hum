import Foundation
import Observation

/// All user preferences, persisted to `UserDefaults`.
///
/// An `@Observable` store (rather than scattered `@AppStorage`) so AppKit-side managers
/// can observe settings too. Keys match the earlier `@AppStorage` keys.
@Observable
@MainActor
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    // Lyrics window
    var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    var lyricAlignment: LyricAlignment { didSet { defaults.set(lyricAlignment.rawValue, forKey: "lyricAlignment") } }
    var visibleLinesMode: VisibleLinesMode { didSet { defaults.set(visibleLinesMode.rawValue, forKey: "visibleLinesMode") } }
    var compactMode: Bool { didSet { defaults.set(compactMode, forKey: "compactMode") } }
    var windowOpacity: Double { didSet { defaults.set(windowOpacity, forKey: "windowOpacity") } }
    var floatOnTop: Bool { didSet { defaults.set(floatOnTop, forKey: "floatOnTop") } }
    var tintWithAlbumColors: Bool { didSet { defaults.set(tintWithAlbumColors, forKey: "tintWithAlbumColors") } }
    var lyricEffect: LyricEffectKind { didSet { defaults.set(lyricEffect.rawValue, forKey: "lyricEffect") } }

    var menuBarLyrics: Bool { didSet { defaults.set(menuBarLyrics, forKey: "menuBarLyrics") } }

    // Island
    var islandEnabled: Bool { didSet { defaults.set(islandEnabled, forKey: "islandEnabled") } }
    var islandShowsOverFullScreen: Bool { didSet { defaults.set(islandShowsOverFullScreen, forKey: "islandShowsOverFullScreen") } }
    var islandShowsLyrics: Bool { didSet { defaults.set(islandShowsLyrics, forKey: "islandShowsLyrics") } }
    var islandPeekOnTrackChange: Bool { didSet { defaults.set(islandPeekOnTrackChange, forKey: "islandPeekOnTrackChange") } }

    // Desktop
    var desktopMode: DesktopMode { didSet { defaults.set(desktopMode.rawValue, forKey: "desktopMode") } }
    var desktopLyricsBackground: DesktopLyricsBackground {
        didSet { defaults.set(desktopLyricsBackground.rawValue, forKey: "desktopLyricsBackground") }
    }

    // Cinematic scene (idle screen, desktop, screensaver)
    var idleStyle: IdleStyle { didSet { defaults.set(idleStyle.rawValue, forKey: "idleStyle") } }
    var cinematicEffect: LyricEffectKind { didSet { defaults.set(cinematicEffect.rawValue, forKey: "cinematicEffect") } }
    /// Write the screensaver feed. Turned on when the user installs the Hum screensaver.
    var screensaverFeed: Bool { didSet { defaults.set(screensaverFeed, forKey: "screensaverFeed") } }

    // Idle screen & sounds
    /// Minutes of inactivity before the idle screen appears; 0 = off.
    var idleMinutes: Int { didSet { defaults.set(idleMinutes, forKey: "idleMinutes") } }
    var needleDropSound: Bool { didSet { defaults.set(needleDropSound, forKey: "needleDropSound") } }
    var crackleSound: Bool { didSet { defaults.set(crackleSound, forKey: "crackleSound") } }
    var soundVolume: Double { didSet { defaults.set(soundVolume, forKey: "soundVolume") } }

    // Playback
    var preferredPlayer: PreferredPlayer { didSet { defaults.set(preferredPlayer.rawValue, forKey: "preferredPlayer") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 18
        lyricAlignment = LyricAlignment(rawValue: defaults.string(forKey: "lyricAlignment") ?? "") ?? .leading
        visibleLinesMode = VisibleLinesMode(rawValue: defaults.string(forKey: "visibleLinesMode") ?? "") ?? .all
        compactMode = defaults.bool(forKey: "compactMode")
        windowOpacity = defaults.object(forKey: "windowOpacity") as? Double ?? 0.95
        floatOnTop = defaults.object(forKey: "floatOnTop") as? Bool ?? true
        tintWithAlbumColors = defaults.object(forKey: "tintWithAlbumColors") as? Bool ?? true
        lyricEffect = LyricEffectKind(rawValue: defaults.string(forKey: "lyricEffect") ?? "") ?? .karaokeFill
        menuBarLyrics = defaults.bool(forKey: "menuBarLyrics")
        islandEnabled = defaults.object(forKey: "islandEnabled") as? Bool ?? true
        islandShowsOverFullScreen = defaults.bool(forKey: "islandShowsOverFullScreen")
        islandShowsLyrics = defaults.object(forKey: "islandShowsLyrics") as? Bool ?? true
        islandPeekOnTrackChange = defaults.object(forKey: "islandPeekOnTrackChange") as? Bool ?? true
        desktopMode = DesktopMode(rawValue: defaults.string(forKey: "desktopMode") ?? "") ?? .off
        desktopLyricsBackground = DesktopLyricsBackground(rawValue: defaults.string(forKey: "desktopLyricsBackground") ?? "") ?? .wallpaper
        idleStyle = IdleStyle(rawValue: defaults.string(forKey: "idleStyle") ?? "") ?? .cinematic
        cinematicEffect = LyricEffectKind(rawValue: defaults.string(forKey: "cinematicEffect") ?? "") ?? .constellation
        screensaverFeed = defaults.bool(forKey: "screensaverFeed")
        idleMinutes = defaults.integer(forKey: "idleMinutes")
        needleDropSound = defaults.bool(forKey: "needleDropSound")
        crackleSound = defaults.bool(forKey: "crackleSound")
        soundVolume = defaults.object(forKey: "soundVolume") as? Double ?? 0.5
        preferredPlayer = PreferredPlayer(rawValue: defaults.string(forKey: "preferredPlayer") ?? "") ?? .auto
    }
}
