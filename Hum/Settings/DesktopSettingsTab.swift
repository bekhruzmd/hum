import SwiftUI

struct DesktopSettingsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Live desktop mode", selection: $settings.desktopMode) {
                    ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if settings.desktopMode == .lyrics {
                    Picker("Background styling", selection: $settings.desktopLyricsBackground) {
                        ForEach(DesktopLyricsBackground.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            } header: {
                Text("Desktop Wallpaper Surface")
            } footer: {
                Text("Renders lyrics or a turntable directly on your Mac desktop behind icons and open windows. Automatically throttles and pauses during full-screen apps, lock screen, and Low Power Mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
