import SwiftUI

struct LyricsSettingsTab: View {
    @Bindable var settings: SettingsStore
    let palette: AlbumPalette

    var body: some View {
        Form {
            Section {
                Picker("Animation effect", selection: $settings.lyricEffect) {
                    ForEach(LyricEffectKind.allCases) { Text($0.displayName).tag($0) }
                }
                EffectPreview(kind: settings.lyricEffect, palette: palette, alignment: settings.lyricAlignment)
            } header: {
                Text("Lyric Animation Style")
            } footer: {
                Text("Word-by-word highlight matches vocal timing. With macOS Reduce Motion enabled, animations become smooth crossfades.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Typography & Layout") {
                LabeledSlider(title: "Font size", value: $settings.fontSize, range: 14...28, step: 1) {
                    "\(Int($0)) pt"
                }
                Picker("Text alignment", selection: $settings.lyricAlignment) {
                    ForEach(LyricAlignment.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Visible lines", selection: $settings.visibleLinesMode) {
                    ForEach(VisibleLinesMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Lyrics Window Appearance") {
                LabeledSlider(title: "Window opacity", value: $settings.windowOpacity, range: 0.35...1.0, step: 0.05) {
                    "\(Int($0 * 100))%"
                }
                Toggle("Keep window floating on top of all apps", isOn: $settings.floatOnTop)
                Toggle("Tint background dynamically with album colors", isOn: $settings.tintWithAlbumColors)
                Toggle("Compact subtitle mode (minimal single line)", isOn: $settings.compactMode)
                Toggle("Show active lyric line in macOS menu bar", isOn: $settings.menuBarLyrics)
            }

            Section("Timing & Synchronization") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fine-tune per-song timing")
                            .font(.subheadline.weight(.medium))
                        Text("Use ⌘] to nudge lyrics 0.1s earlier or ⌘[ to nudge later while viewing lyrics. Hum automatically saves and remembers your timing adjustment per track.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
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
