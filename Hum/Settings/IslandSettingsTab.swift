import SwiftUI

struct IslandSettingsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Show the island", isOn: $settings.islandEnabled)
                Toggle("Show the current lyric when expanded", isOn: $settings.islandShowsLyrics)
                    .disabled(!settings.islandEnabled)
                Toggle("Show over full-screen apps", isOn: $settings.islandShowsOverFullScreen)
                    .disabled(!settings.islandEnabled)
            } footer: {
                Text("On a Mac with a notch, the island wraps the notch. Elsewhere it's a small pill under the menu bar. Hover to expand, click the cover to open lyrics, swipe sideways with two fingers to skip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
