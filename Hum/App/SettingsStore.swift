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

    // Island
    var islandEnabled: Bool { didSet { defaults.set(islandEnabled, forKey: "islandEnabled") } }
    var islandShowsOverFullScreen: Bool { didSet { defaults.set(islandShowsOverFullScreen, forKey: "islandShowsOverFullScreen") } }
    var islandShowsLyrics: Bool { didSet { defaults.set(islandShowsLyrics, forKey: "islandShowsLyrics") } }

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
        islandEnabled = defaults.object(forKey: "islandEnabled") as? Bool ?? true
        islandShowsOverFullScreen = defaults.bool(forKey: "islandShowsOverFullScreen")
        islandShowsLyrics = defaults.object(forKey: "islandShowsLyrics") as? Bool ?? true
        preferredPlayer = PreferredPlayer(rawValue: defaults.string(forKey: "preferredPlayer") ?? "") ?? .auto
    }
}
