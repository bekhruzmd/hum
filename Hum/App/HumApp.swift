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
