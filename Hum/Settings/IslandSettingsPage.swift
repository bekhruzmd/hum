import SwiftUI

struct IslandSettingsPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsPageScaffold(page: .island) {
            Section {
                FeatureToggleRow(title: "Island", caption: "Around the notch while music plays (a pill under the menu bar on other displays)",
                                 isOn: $settings.islandEnabled)
                PreviewWell(height: 190) {
                    IslandPreview(motion: settings.islandMotion, size: settings.islandSize, showsBars: settings.islandShowsBars,
                                  material: settings.surfaceMaterial)
                }
            }

            Section {
                MaterialPicker(selection: $settings.surfaceMaterial)
            } header: {
                Text("Material")
            } footer: {
                Text("Also used by the glass music player on the idle scene and screensaver, and by the lyrics window's controls.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!settings.islandEnabled)

            Section {
                Picker("Open with", selection: $settings.islandTrigger) {
                    ForEach(IslandTrigger.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.islandTrigger == .hover {
                    LabeledSlider(title: "Hover delay", value: $settings.islandHoverDelay, range: 0...0.6, step: 0.02) { value in
                        value < 0.01 ? "None" : String(format: "%.2f s", value)
                    }
                }
                Picker("Motion", selection: $settings.islandMotion) {
                    ForEach(IslandMotion.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Haptic feedback on open", isOn: $settings.islandHaptics)
            } header: {
                Text("Opening")
            } footer: {
                Text("You can also pull the island down with a drag or a two-finger swipe, and push it back up. When it's open, swipe sideways or click the dots to switch between Player and Lyrics.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!settings.islandEnabled)

            Section("Layout") {
                Picker("Size", selection: $settings.islandSize) {
                    ForEach(IslandSize.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Lyrics page", isOn: $settings.islandShowsLyrics)
                Toggle("Visualizer bars when closed", isOn: $settings.islandShowsBars)
            }
            .disabled(!settings.islandEnabled)

            Section("Behavior") {
                Toggle("Peek open when the song changes", isOn: $settings.islandPeekOnTrackChange)
                if settings.islandPeekOnTrackChange {
                    LabeledSlider(title: "Peek length", value: $settings.islandPeekDuration, range: 1...8, step: 0.5) {
                        String(format: "%.1f s", $0)
                    }
                }
                Toggle("Show over full-screen apps", isOn: $settings.islandShowsOverFullScreen)
            }
            .disabled(!settings.islandEnabled)
        }
    }
}

/// A miniature notch that keeps opening and closing with the chosen motion and size, so the
/// settings can be felt before trying them. Its loop runs only while the page is visible.
struct IslandPreview: View {
    let motion: IslandMotion
    let size: IslandSize
    let showsBars: Bool
    var material: SurfaceMaterial = .frosted

    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The preview is drawn at this fraction of real size.
    private let scale: CGFloat = 0.62
    private let notch = CGSize(width: 188, height: 32)

    var body: some View {
        let closed = CGSize(width: (notch.width + 2 * IslandGeometry.earWidth) * scale, height: notch.height * scale)
        let expanded = CGSize(width: size.expanded.width * scale, height: (size.expanded.height + notch.height) * scale)
        let current = open ? expanded : closed
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.22, blue: 0.38), Color(red: 0.36, green: 0.28, blue: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Menu bar strip.
            Rectangle().fill(.black.opacity(0.25)).frame(height: notch.height * scale)

            ZStack(alignment: .top) {
                let shape = IslandShape(shoulder: (open ? 10 : 7) * scale, bottomRadius: (open ? 26 : 11) * scale)
                ZStack {
                    SurfaceBackground(material: material, shape: shape, darkening: material == .liquidGlass ? 0.25 : 0.5)
                    shape.fill(LinearGradient(stops: [
                        .init(color: .black, location: 0), .init(color: .black, location: 0.2),
                        .init(color: .black.opacity(0.3), location: 0.45), .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    shape.fill(.black).opacity(open ? 0 : 1)
                }
                Group {
                    if open {
                        openContent(width: expanded.width)
                            .frame(width: expanded.width, height: expanded.height, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                .animation(motion.open.delay(0.05)))
                    } else {
                        closedContent(width: closed.width)
                            .transition(.opacity)
                    }
                }
                .frame(width: current.width, height: current.height, alignment: .top)
                .mask(shape)
            }
            .frame(width: current.width, height: current.height)
            .shadow(color: .black.opacity(open ? 0.35 : 0), radius: 14, y: 6)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : (open ? motion.open : motion.close), value: open)
        }
        .environment(\.colorScheme, .dark)
        .task(id: "\(motion.rawValue)-\(size.rawValue)") {
            open = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                open = true
                try? await Task.sleep(for: .milliseconds(1900))
                open = false
            }
        }
        .accessibilityLabel("Preview of the island opening and closing")
    }

    private func closedContent(width: CGFloat) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom))
                .frame(width: 13, height: 13)
            Spacer()
            if showsBars {
                PlaybackBars(isPlaying: true, color: .pink, barWidth: 1.6, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: notch.height * scale)
    }

    private func openContent(width: CGFloat) -> some View {
        let art = size.artworkSize * scale
        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 3) {
                    Capsule().fill(.white).frame(width: 9, height: 3.5)
                    Circle().fill(.white.opacity(0.35)).frame(width: 3.5, height: 3.5)
                }
                Spacer()
                Circle().fill(.white.opacity(0.15)).frame(width: 13, height: 13)
            }
            .frame(height: notch.height * scale)
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: art * 0.2).fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: art, height: art)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(.white.opacity(0.9)).frame(width: 60, height: 5)
                    Capsule().fill(.white.opacity(0.45)).frame(width: 40, height: 4)
                }
                Spacer()
                if showsBars { PlaybackBars(isPlaying: true, color: .white.opacity(0.85), barWidth: 1.6, height: 9) }
            }
            Capsule().fill(.white.opacity(0.22)).frame(height: 2.5)
                .overlay(alignment: .leading) { Capsule().fill(.white.opacity(0.9)).frame(width: width * 0.3, height: 2.5) }
            HStack(spacing: 18) {
                Image(systemName: "backward.fill")
                Image(systemName: "pause.fill").font(.system(size: 15, weight: .semibold))
                Image(systemName: "forward.fill")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 22 * scale)
    }
}

/// Liquid Glass / Frosted / Solid, with a note when Liquid Glass isn't available.
struct MaterialPicker: View {
    @Binding var selection: SurfaceMaterial
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Picker("Material", selection: $selection) {
            ForEach(SurfaceMaterial.allCases) { material in
                Text(material.displayName).tag(material)
                    .disabled(material == .liquidGlass && !SurfaceMaterial.isLiquidGlassAvailable)
            }
        }
        .pickerStyle(.segmented)
        if !SurfaceMaterial.isLiquidGlassAvailable {
            Text("Liquid Glass needs macOS 26 or later; Frosted is used instead.")
                .font(.caption).foregroundStyle(.secondary)
        } else if reduceTransparency && selection != .solid {
            Text("Reduce Transparency is on, so surfaces are drawn solid.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
