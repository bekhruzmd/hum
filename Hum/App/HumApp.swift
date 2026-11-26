import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(environment: AppEnvironment.shared)
        } label: {
            MenuBarLabel(ticker: AppEnvironment.shared.ticker)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { AppEnvironment.shared.windows.showSettings() }
                    .keyboardShortcut(",")
            }
            CommandGroup(after: .windowArrangement) {
                Button("Show Mini Player") { AppEnvironment.shared.windows.showMiniPlayer() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Show Live Scene") { AppEnvironment.shared.windows.showCinematicPreview() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

/// The ♪ icon, or the current lyric line when "Lyrics in menu bar" is on.
struct MenuBarLabel: View {
    let ticker: LyricsTicker

    var body: some View {
        if let line = ticker.line {
            Text(line)
        } else {
            Image(systemName: "music.note")
        }
    }
}
