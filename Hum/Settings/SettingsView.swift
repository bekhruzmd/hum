import SwiftUI

/// The Settings window: one tab per feature area.
struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            LyricsSettingsTab(settings: environment.settings, palette: environment.nowPlaying.palette)
                .tabItem { Label("Lyrics", systemImage: "text.quote") }
            IslandSettingsTab(settings: environment.settings)
                .tabItem { Label("Island", systemImage: "capsule.tophalf.filled") }
            GeneralSettingsTab(settings: environment.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
