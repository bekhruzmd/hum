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
    let onCompact: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(image: artwork, size: 48, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

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
    }
}
