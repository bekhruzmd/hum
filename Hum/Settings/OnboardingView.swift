import SwiftUI

/// First-run welcome: one screen, not a wizard. It shows what Hum does and teaches the
/// shortcut model by having you press one.
struct OnboardingView: View {
    static let size = CGSize(width: 480, height: 524)

    let environment: AppEnvironment
    let onFinish: () -> Void

    @State private var baselineTriggers = 0
    @State private var triedShortcut = false

    private var lyricsCombo: KeyCombo? { environment.hotkeyStore.bindings[.showLyrics] }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 28) // under the traffic lights

            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                    .accessibilityHidden(true)
            }
            Text("Welcome to Hum")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .padding(.top, 12)
            Text("Lyrics and controls for whatever plays in Spotify or Apple Music.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                feature(.island, title: "The island", detail: "Hover the notch for controls, the scrubber and lyrics.")
                feature(.lyrics, title: "Synced lyrics", detail: "Word by word, in the lyrics window and the menu bar.")
                feature(.screenSaver, title: "Idle scene", detail: "A calm scene with the player when you step away.")
            }
            .padding(.top, 24)
            .padding(.horizontal, 36)

            tryIt
                .padding(.top, 22)
                .padding(.horizontal, 28)

            Spacer(minLength: 12)

            Text("macOS will ask to let Hum see what Spotify or Music is playing. Click Allow.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack {
                Button("Open Settings") {
                    environment.windows.showSettings()
                    onFinish()
                }
                Spacer()
                Button("Get Started", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .windowBackground))
        .ignoresSafeArea()
        .background {
            Button("", action: onFinish).keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        }
        .onAppear { baselineTriggers = environment.hotkeyStore.triggerCount }
        .onChange(of: environment.hotkeyStore.triggerCount) { _, count in
            if count > baselineTriggers, environment.hotkeyStore.lastTriggered == .showLyrics {
                withAnimation(.spring(response: 0.35, dampingFraction: 1)) { triedShortcut = true }
            }
        }
    }

    private func feature(_ page: SettingsPage, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            SettingsIconTile(page: page, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Teach by doing: press the shortcut, see it work.
    private var tryIt: some View {
        HStack(spacing: 12) {
            Image(systemName: triedShortcut ? "checkmark.circle.fill" : "keyboard")
                .font(.system(size: 20))
                .foregroundStyle(triedShortcut ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 4) {
                if triedShortcut {
                    Text("That's it.").font(.system(size: 13, weight: .semibold))
                    Text("Every Hum shortcut works from any app. Change them in Settings › Keys.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else if let combo = lyricsCombo {
                    HStack(spacing: 6) {
                        Text("Try it: press").font(.system(size: 13, weight: .semibold))
                        KeyCaps(combo: combo)
                    }
                    Text("It opens the lyrics window, from any app.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    Text("Open lyrics from the ♪ in the menu bar.").font(.system(size: 13, weight: .semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

/// A shortcut drawn as small key caps, e.g. ⌃ ⌥ L.
struct KeyCaps: View {
    let combo: KeyCombo

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(Self.parts(of: combo).enumerated()), id: \.offset) { _, part in
                Text(part)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
            }
        }
        .accessibilityLabel(combo.displayString)
    }

    static func parts(of combo: KeyCombo) -> [String] {
        let display = combo.displayString
        let modifiers = display.prefix { "⌃⌥⇧⌘".contains($0) }.map(String.init)
        return modifiers + [String(display.dropFirst(modifiers.count))]
    }
}
