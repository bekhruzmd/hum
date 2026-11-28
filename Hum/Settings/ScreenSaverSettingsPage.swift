import SwiftUI

struct ScreenSaverSettingsPage: View {
    let environment: AppEnvironment

    private static let idleChoices = [0, 2, 5, 10, 15, 30]

    /// A MacBook-shaped display for the still preview, so it doesn't depend on the real screen.
    private static let previewDisplay = DisplayEdgeGeometry.make(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeTop: 32,
        left: CGRect(x: 0, y: 950, width: 662, height: 32), right: CGRect(x: 850, y: 950, width: 662, height: 32),
        isBuiltIn: true
    )

    var body: some View {
        @Bindable var settings = environment.settings
        SettingsPageScaffold(page: .screenSaver) {
            Section {
                FeatureToggleRow(title: "Record and Player", caption: "On the idle scene and screensaver, while music plays",
                                 isOn: $settings.idlePlayerBar)
                PreviewWell(height: 250) {
                    CinematicScene(data: environment.cinematicData(), animate: false,
                                   displayOverride: Self.previewDisplay)
                        .aspectRatio(1512 / 982, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(white: 0.06))
                        .allowsHitTesting(false)
                }
                Text("On Hum's idle scene the player is interactive: move the mouse to show it, then pause, skip or scrub. A key press or a click on empty space closes the scene. In the macOS screensaver the player is display-only, because macOS ends a screensaver on any mouse movement or key press.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Idle scene") {
                Picker("Start", selection: $settings.idleMinutes) {
                    ForEach(Self.idleChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Only when I ask" : "After \(minutes) minutes idle").tag(minutes)
                    }
                }
                Picker("Style", selection: $settings.idleStyle) {
                    ForEach(IdleStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Look", selection: $settings.cinematicLook) {
                    ForEach(CinematicLook.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Lyrics", selection: $settings.cinematicEffect) {
                    ForEach(LyricEffectKind.allCases) { Text($0.displayName).tag($0) }
                }
                HStack {
                    Spacer()
                    Button {
                        environment.idleScreen.show()
                    } label: {
                        Label("Show Idle Scene", systemImage: "play.rectangle")
                    }
                }
            }

            ScreensaverSection(settings: settings, writer: environment.screensaverFeed,
                               preview: environment.windows.showCinematicPreview)
        }
    }
}

/// Install the Hum screensaver and keep its feed on.
struct ScreensaverSection: View {
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
