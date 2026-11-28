import SwiftUI

/// The menu bar menu: what's playing, playback, surfaces, and the app. Every action that has a
/// global shortcut shows it, so the menu doubles as a reminder of the shortcuts.
struct MenuBarContent: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings
        let windows = environment.windows
        let nowPlaying = environment.nowPlaying
        let keys = environment.hotkeyStore.bindings
        let hasTrack = nowPlaying.currentTrack != nil

        if let track = nowPlaying.currentTrack {
            Text("\(track.title) — \(track.artist)")
            Divider()
        } else {
            Text("Nothing Playing")
            Divider()
        }

        // Playback
        Button(nowPlaying.isPlaying ? "Pause" : "Play") { nowPlaying.playPause() }
            .globalShortcut(keys[.playPause])
            .disabled(!hasTrack)
        Button("Next Track") { nowPlaying.nextTrack() }
            .globalShortcut(keys[.nextTrack])
            .disabled(!hasTrack)
        Button("Previous Track") { nowPlaying.previousTrack() }
            .globalShortcut(keys[.previousTrack])
            .disabled(!hasTrack)

        Divider()

        // Windows
        Button(windows.isLyricsVisible ? "Hide Lyrics Window" : "Show Lyrics Window") { windows.toggleLyrics() }
            .globalShortcut(keys[.showLyrics])
        Button(windows.isMiniPlayerVisible ? "Hide Mini Player" : "Show Mini Player") { windows.toggleMiniPlayer() }
        Button("Start Idle Scene") { environment.idleScreen.show() }
            .globalShortcut(keys[.idleScreen])

        Divider()

        // Surfaces
        Toggle("Island", isOn: $settings.islandEnabled)
        Toggle("Beat Glow", isOn: $settings.beatGlowEnabled)
        Toggle("Lyrics in Menu Bar", isOn: $settings.menuBarLyrics)
        Picker("Desktop", selection: $settings.desktopMode) {
            ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
        }
        Menu("Lyrics Offset") {
            Button("Earlier (+0.1 s)") { environment.nudgeOffset(by: OffsetStore.step) }
                .globalShortcut(keys[.offsetEarlier])
            Button("Later (−0.1 s)") { environment.nudgeOffset(by: -OffsetStore.step) }
                .globalShortcut(keys[.offsetLater])
            Divider()
            Button("Reset Offset") { environment.offsets.reset(nowPlaying.currentTrack) }
        }
        .disabled(!hasTrack)

        Divider()

        Button("Show Live Scene") { windows.showCinematicPreview() }
        Button("Settings…") { windows.showSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Hum") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
