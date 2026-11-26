import AppKit
import SwiftUI

struct ArtworkView: View {
    let image: NSImage?
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(size <= 32 ? .caption : .title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct HeaderView: View {
    let track: Track
    let artwork: NSImage?
    let isPlaying: Bool
    let offset: TimeInterval
    let onCompact: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(image: artwork, size: 48, cornerRadius: 8)
                .id(track.albumKey)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if offset != 0 {
                Text(String(format: "%+.1fs", offset))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .help("Lyrics offset for this song. ⌘] earlier, ⌘[ later, ⌘0 reset.")
                    .accessibilityLabel(String(format: "Lyrics offset %+.1f seconds", offset))
            }

            Image(systemName: isPlaying ? "waveform" : "pause.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                .accessibilityLabel(isPlaying ? "Playing" : "Paused")

            Button(action: onCompact) {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Compact subtitle mode")
            .accessibilityLabel("Compact subtitle mode")
        }
        .animation(.easeInOut(duration: 0.4), value: track)
        .animation(.easeInOut(duration: 0.4), value: artwork)
    }
}
