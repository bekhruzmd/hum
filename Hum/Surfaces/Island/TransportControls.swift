import SwiftUI

/// Previous / play-pause / next, used by the lyrics window and Settings.
struct TransportControls: View {
    let nowPlaying: NowPlayingStore
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            button("backward.fill", label: "Previous track", size: 13) { nowPlaying.previousTrack() }
            button(isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play", size: 19) {
                nowPlaying.playPause()
            }
            button("forward.fill", label: "Next track", size: 13) { nowPlaying.nextTrack() }
        }
        .foregroundStyle(.primary)
    }

    private func button(_ symbol: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusicBarButtonStyle())
        .accessibilityLabel(label)
    }
}
