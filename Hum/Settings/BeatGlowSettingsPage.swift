import SwiftUI

struct BeatGlowSettingsPage: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings
        let appearance = $settings.glowAppearance
        SettingsPageScaffold(page: .beatGlow) {
            Section {
                FeatureToggleRow(title: "Beat Glow", caption: "A line of light around your screen while music plays, flaring with each sung word",
                                 isOn: $settings.beatGlowEnabled)
                PreviewWell(height: 210) {
                    GlowPreview(appearance: settings.glowAppearance, intensity: settings.beatGlowIntensity,
                                palette: environment.nowPlaying.palette)
                }
            }

            Section("Color") {
                Picker("Color", selection: appearance.colorMode) {
                    ForEach(GlowColorMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.glowAppearance.colorMode == .custom {
                    ColorPicker("Glow color", selection: Binding(
                        get: { settings.glowAppearance.customColor.color },
                        set: { settings.glowAppearance.customColor = RGB($0) }
                    ), supportsOpacity: false)
                }
                if settings.glowAppearance.colorMode == .album {
                    Text("Picks the most luminous color from the current album cover.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Motion") {
                Picker("Style", selection: appearance.style) {
                    ForEach(GlowStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Flare with the singing", isOn: appearance.followsLyrics)
                LabeledSlider(title: "Speed", value: appearance.speed, range: 0.25...3, step: 0.05) {
                    String(format: "%.2g×", $0)
                }
                .disabled(settings.glowAppearance.style == .steady && settings.glowAppearance.colorMode != .spectrum)
            }

            Section {
                LabeledSlider(title: "Brightness", value: $settings.beatGlowIntensity, range: 0.2...3, step: 0.05) {
                    "\(Int(($0 * 100).rounded()))%"
                }
                LabeledSlider(title: "Thickness", value: appearance.thickness, range: 0.5...2.5, step: 0.05) {
                    String(format: "%.2g×", $0)
                }
                LabeledSlider(title: "Idle scene & screensaver", value: $settings.cinematicEdgeGlow, range: 0...3, step: 0.1) {
                    $0 == 0 ? "Off" : "\(Int(($0 * 100).rounded()))%"
                }
                DisplayEdgeSettings(settings: settings)
            } header: {
                Text("Light")
            } footer: {
                Text("Color and motion also apply to the glow in the idle scene and the Hum screensaver. Flares follow the lyric word timing; songs without synced lyrics get a gentle breath.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// A small dark "display" with the glow running and pulsing to a steady beat.
struct GlowPreview: View {
    let appearance: GlowAppearance
    let intensity: Double
    let palette: AlbumPalette

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let display = DisplayEdgeGeometry.make(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeTop: 32,
        left: CGRect(x: 0, y: 950, width: 662, height: 32), right: CGRect(x: 850, y: 950, width: 662, height: 32),
        isBuiltIn: true
    )

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height - 16
            let size = CGSize(width: height * 1512 / 982, height: height)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                // 116 bpm stand-in for word onsets.
                let beat = appearance.followsLyrics ? exp(-t.truncatingRemainder(dividingBy: 60.0 / 116) / BeatPulse.decay) : BeatPulse.breath(at: t)
                ZStack {
                    Color(white: 0.03)
                    DisplayEdgeGlow(
                        contour: Self.display.resolved(in: size), time: t, intensity: intensity,
                        color: appearance.color(for: palette), appearance: appearance, pulse: beat
                    )
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(white: 0.09))
        .accessibilityLabel("Preview of Beat Glow")
    }
}
