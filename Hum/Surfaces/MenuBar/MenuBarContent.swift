import SwiftUI

struct MenuBarContent: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings
        let windows = environment.windows

        if let track = environment.nowPlaying.currentTrack {
            Text("\(track.title) — \(track.artist)")
                .font(.headline)
            Divider()
        }

        // Core Window Actions
        Button(windows.isLyricsVisible ? "Hide Lyrics Window" : "Show Lyrics Window") {
            windows.toggleLyrics()
        }

        Button(windows.isMiniPlayerVisible ? "Hide Mini Player" : "Show Mini Player") {
            windows.toggleMiniPlayer()
        }

        Button("Show Live Scene") {
            windows.showCinematicPreview()
        }

        Divider()

        // Display Surfaces & Offsets
        Menu("Desktop") {
            ForEach(DesktopMode.allCases) { mode in
                Button {
                    settings.desktopMode = mode
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if settings.desktopMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Menu("Lyrics Offset") {
            Button("Earlier (+0.1 s)") { environment.nudgeOffset(by: OffsetStore.step) }
            Button("Later (−0.1 s)") { environment.nudgeOffset(by: -OffsetStore.step) }
            Divider()
            Button("Reset Offset") { environment.offsets.reset(environment.nowPlaying.currentTrack) }
        }
        .disabled(environment.nowPlaying.currentTrack == nil)

        Button("Start Idle Screen") {
            environment.idleScreen.show()
        }

        Divider()

        // App Management
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
