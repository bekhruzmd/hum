import SwiftUI

struct IslandSettingsPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsPageScaffold(page: .island) {
            Section {
                FeatureToggleRow(title: "Island", caption: "Around the notch while music plays (a pill under the menu bar on other displays)",
                                 isOn: $settings.islandEnabled)
                PreviewWell(height: 190) {
                    IslandPreview(motion: settings.islandMotion, size: settings.islandSize, showsBars: settings.islandShowsBars)
                }
            }

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
                Text("You can also pull the island down with a drag or a two-finger swipe, and push it back up. When it's open, swipe sideways to skip.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!settings.islandEnabled)

            Section("Layout") {
                Picker("Size", selection: $settings.islandSize) {
                    ForEach(IslandSize.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Current lyric line", isOn: $settings.islandShowsLyrics)
                    .disabled(settings.islandSize == .compact)
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
                IslandShape(shoulder: (open ? 18 : 7) * scale, bottomRadius: (open ? 32 : 11) * scale).fill(.black)
                Group {
                    if open {
                        openContent(width: expanded.width)
                            .frame(width: expanded.width, height: expanded.height, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top))
                                .animation(motion.open.delay(0.06)))
                    } else {
                        closedContent(width: closed.width)
                            .transition(.opacity)
                    }
                }
                .frame(width: current.width, height: current.height, alignment: .top)
                .mask(IslandShape(shoulder: (open ? 18 : 7) * scale, bottomRadius: (open ? 32 : 11) * scale))
            }
            .frame(width: current.width, height: current.height)
            .shadow(color: .black.opacity(open ? 0.4 : 0), radius: 12, y: 6)
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
        VStack(spacing: 7) {
            Color.clear.frame(height: notch.height * scale - 2)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size.artworkSize * scale, height: size.artworkSize * scale)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(.white.opacity(0.85)).frame(width: 70, height: 6)
                    Capsule().fill(.white.opacity(0.4)).frame(width: 46, height: 5)
                }
                Spacer()
                HStack(spacing: 9) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill").font(.system(size: 12))
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 8))
                .foregroundStyle(.white)
            }
            if size != .compact {
                Capsule().fill(.white.opacity(0.7)).frame(width: width * 0.45, height: 5)
            }
            Capsule().fill(.white.opacity(0.2)).frame(height: 3)
                .overlay(alignment: .leading) { Capsule().fill(.pink).frame(width: width * 0.25, height: 3) }
        }
        .padding(.horizontal, 22 * scale)
    }
}
