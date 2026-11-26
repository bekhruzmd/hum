import SwiftUI

struct DesktopSettingsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Live desktop", selection: $settings.desktopMode) {
                    ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.desktopMode == .lyrics {
                    Picker("Background", selection: $settings.desktopLyricsBackground) {
                        ForEach(DesktopLyricsBackground.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            } footer: {
                Text("Draws on every display, above your wallpaper and below your desktop icons. It never takes clicks, and it pauses when covered, when the screen is locked, or in Low Power Mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
