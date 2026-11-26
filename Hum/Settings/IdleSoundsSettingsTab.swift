import SwiftUI

struct IdleSoundsSettingsTab: View {
    let environment: AppEnvironment

    private static let idleChoices = [0, 2, 5, 10, 15, 30]

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
                Picker("Show after", selection: $settings.idleMinutes) {
                    ForEach(Self.idleChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Never" : "\(minutes) minutes idle").tag(minutes)
                    }
                }
                Picker("Style", selection: $settings.idleStyle) {
                    ForEach(IdleStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Cinematic lyrics", selection: $settings.cinematicEffect) {
                    ForEach(LyricEffectKind.allCases) { Text($0.displayName).tag($0) }
                }
                Button("Preview idle screen") { environment.idleScreen.show() }
            } header: {
                Text("Idle screen")
            } footer: {
                Text("Appears only while music plays. Any key, click or mouse move dismisses it. The macOS screensaver and lock screen always appear on top.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Needle drop when playback starts", isOn: $settings.needleDropSound)
                Toggle("Soft vinyl crackle while playing", isOn: $settings.crackleSound)
                LabeledSlider(title: "Volume", value: $settings.soundVolume, range: 0...1, step: 0.05) {
                    "\(Int($0 * 100))%"
                }
                Button("Play needle drop") { environment.sounds.playNeedleDrop(volume: Float(settings.soundVolume)) }
            } header: {
                Text("Sounds")
            } footer: {
                Text("Hum's sounds are generated on your Mac by its own code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
