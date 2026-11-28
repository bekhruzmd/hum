import SwiftUI

/// Previous / play-pause / next, used by the lyrics window and Settings.
struct TransportControls: View {
    let nowPlaying: NowPlayingStore
    let isPlaying: Bool
    /// Shortcut shown in each button's tooltip, e.g. "Space" or "⌃⌥→".
    var hint: (HotkeyAction) -> String? = { _ in nil }

    var body: some View {
        HStack(spacing: 14) {
            button("backward.fill", label: "Previous track", shortcut: hint(.previousTrack), size: 13) { nowPlaying.previousTrack() }
            button(isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play",
                   shortcut: hint(.playPause), size: 19) {
                nowPlaying.playPause()
            }
            button("forward.fill", label: "Next track", shortcut: hint(.nextTrack), size: 13) { nowPlaying.nextTrack() }
        }
        .foregroundStyle(.primary)
    }

    private func button(_ symbol: String, label: String, shortcut: String?, size: CGFloat,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusicBarButtonStyle())
        .help(shortcut.map { "\(label)  \($0)" } ?? label)
        .accessibilityLabel(label)
    }
}
