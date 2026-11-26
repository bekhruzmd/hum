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
        Toggle("Show Island", isOn: $settings.islandEnabled)
        Picker("Desktop", selection: $settings.desktopMode) {
            ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
        }
        Toggle("Float on Top", isOn: $settings.floatOnTop)
        Toggle("Compact Subtitle Mode", isOn: $settings.compactMode)

        Menu("Lyrics Offset") {
            Button("Earlier (+0.1 s)") { environment.nudgeOffset(by: OffsetStore.step) }
            Button("Later (−0.1 s)") { environment.nudgeOffset(by: -OffsetStore.step) }
            Button("Reset") { environment.offsets.reset(environment.nowPlaying.currentTrack) }
        }
        .disabled(environment.nowPlaying.currentTrack == nil)

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
