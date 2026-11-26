import SwiftUI

/// The Settings window: one tab per feature area.
struct SettingsView: View {
    static let size = CGSize(width: 560, height: 620)

    let environment: AppEnvironment

    var body: some View {
        TabView {
            LyricsSettingsTab(settings: environment.settings, palette: environment.nowPlaying.palette)
                .tabItem { Label("Lyrics", systemImage: "text.quote") }
            IslandSettingsTab(settings: environment.settings)
                .tabItem { Label("Island", systemImage: "capsule.tophalf.filled") }
            DesktopSettingsTab(settings: environment.settings)
                .tabItem { Label("Desktop", systemImage: "menubar.dock.rectangle") }
            IdleSoundsSettingsTab(environment: environment)
                .tabItem { Label("Idle & Sounds", systemImage: "moon.zzz") }
            ShortcutsSettingsTab(store: environment.hotkeyStore)
                .tabItem { Label("Shortcuts", systemImage: "command") }
            GeneralSettingsTab(settings: environment.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
