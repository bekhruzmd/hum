import SwiftUI

struct LyricsSettingsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Text") {
                LabeledSlider(title: "Font size", value: $settings.fontSize, range: 14...28, step: 1) {
                    "\(Int($0)) pt"
                }
                Picker("Alignment", selection: $settings.lyricAlignment) {
                    ForEach(LyricAlignment.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Visible lines", selection: $settings.visibleLinesMode) {
                    ForEach(VisibleLinesMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Window") {
                LabeledSlider(title: "Opacity", value: $settings.windowOpacity, range: 0.35...1.0, step: 0.05) {
                    "\(Int($0 * 100))%"
                }
                Toggle("Float on top", isOn: $settings.floatOnTop)
                Toggle("Tint with album colors", isOn: $settings.tintWithAlbumColors)
                Toggle("Compact subtitle mode", isOn: $settings.compactMode)
            }
        }
        .formStyle(.grouped)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
            Text(format(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
