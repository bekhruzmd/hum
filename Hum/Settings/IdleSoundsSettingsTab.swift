import SwiftUI

struct IdleSoundsSettingsTab: View {
    let environment: AppEnvironment

    private static let idleChoices = [0, 2, 5, 10, 15, 30]

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
                Picker("Start idle scene", selection: $settings.idleMinutes) {
                    ForEach(Self.idleChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Never (Manual Only)" : "After \(minutes) minutes of inactivity").tag(minutes)
                    }
                }
                Picker("Display style", selection: $settings.idleStyle) {
                    ForEach(IdleStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Visual look", selection: $settings.cinematicLook) {
                    ForEach(CinematicLook.allCases) { Text($0.displayName).tag($0) }
                }

                LabeledSlider(title: "Ambient edge glow", value: $settings.cinematicEdgeGlow, range: 0...3, step: 0.1) { value in
                    value == 0 ? "Off" : "\(Int((value * 100).rounded()))%"
                }

                DisplayEdgeSettings(settings: settings)

                Picker("Cinematic lyrics effect", selection: $settings.cinematicEffect) {
                    ForEach(LyricEffectKind.allCases) { Text($0.displayName).tag($0) }
                }

                HStack {
                    Spacer()
                    Button {
                        environment.idleScreen.show()
                    } label: {
                        Label("Preview Fullscreen Idle Scene", systemImage: "play.rectangle.on.rectangle")
                    }
                    .controlSize(.regular)
                }
            } header: {
                Text("Full-Screen Idle Screen")
            } footer: {
                Text("Appears while music is playing. Any keystroke, mouse movement, or click dismisses it instantly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Live desktop wallpaper", selection: $settings.desktopMode) {
                    ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if settings.desktopMode == .lyrics {
                    Picker("Wallpaper background", selection: $settings.desktopLyricsBackground) {
                        ForEach(DesktopLyricsBackground.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            } header: {
                Text("Desktop Wallpaper Surface")
            } footer: {
                Text("Renders lyrics or a cinematic scene directly on your Mac desktop behind icons and open windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScreensaverSection(settings: settings, writer: environment.screensaverFeed, preview: environment.windows.showCinematicPreview)

            Section {
                Toggle("Needle drop when playback begins", isOn: $settings.needleDropSound)
                Toggle("Continuous soft vinyl crackle during playback", isOn: $settings.crackleSound)
                LabeledSlider(title: "Effects volume", value: $settings.soundVolume, range: 0...1, step: 0.05) {
                    "\(Int($0 * 100))%"
                }
                HStack {
                    Spacer()
                    Button {
                        environment.sounds.playNeedleDrop(volume: Float(settings.soundVolume))
                    } label: {
                        Label("Test Needle Drop", systemImage: "speaker.wave.2")
                    }
                    .controlSize(.small)
                }
            } header: {
                Text("Audio Atmosphere")
            } footer: {
                Text("Hum's acoustic effects are procedurally generated in real time on your Mac—no internet connection or audio assets required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Install the Hum screensaver and keep its feed on.
private struct ScreensaverSection: View {
    @Bindable var settings: SettingsStore
    let writer: ScreensaverFeedWriter
    let preview: () -> Void
    @State private var installed = ScreensaverInstaller.isInstalled
    @State private var justInstalled = false
    @State private var error: String?

    var body: some View {
        Section {
            HStack {
                Text(installed ? "Hum screensaver is installed" : "Show Hum as your Mac's screensaver")
                Spacer()
                Button(installed ? "Reinstall" : "Install Screen Saver") { install() }
            }
            Toggle("Send the current song to the screensaver", isOn: $settings.screensaverFeed)
            HStack {
                Button("Preview live scene", action: preview)
                Button("Screen Saver Settings…") { ScreensaverInstaller.openScreenSaverSettings() }
            }
            if settings.screensaverFeed, let message = writer.deliveryError {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
            if justInstalled {
                Label("Installed. Close and reopen System Settings to reload Hum, then choose it under Other.",
                      systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Screensaver")
        } footer: {
            Text("After installing, pick Hum in \(ScreensaverInstaller.settingsLocation). Keep Hum running in the menu bar to receive live songs and lyrics. Your lock settings keep working. No additional file-access permission is needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func install() {
        error = nil
        do {
            try ScreensaverInstaller.install()
            installed = true
            justInstalled = true
            settings.screensaverFeed = true
            ScreensaverInstaller.openScreenSaverSettings()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
