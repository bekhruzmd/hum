import SwiftUI

struct MenuBarContent: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings
        let windows = environment.windows

        if let track = environment.nowPlaying.currentTrack {
            Text("\(track.title) — \(track.artist)")
            Divider()
        }

        Button(windows.isLyricsVisible ? "Hide Lyrics Window" : "Show Lyrics Window") {
            windows.toggleLyrics()
        }
        Toggle("Float on Top", isOn: $settings.floatOnTop)
        Toggle("Compact Subtitle Mode", isOn: $settings.compactMode)

        Divider()

        Button("Settings…") {
            windows.showSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Hum") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
