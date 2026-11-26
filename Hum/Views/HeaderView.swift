import AppKit
import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url {
                if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            placeholderArtwork
                        @unknown default:
                            placeholderArtwork
                        }
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary)
            Image(systemName: "music.note")
                .font(size <= 32 ? .caption : .title3)
                .foregroundStyle(.secondary)
        }
    }
}

struct HeaderView: View {
    let track: Track
    let isPlaying: Bool
    @Binding var compactMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: track.artworkURL, size: 48, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: isPlaying ? "waveform" : "pause.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    compactMode.toggle()
                }
            } label: {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Compact subtitle mode")
        }
    }
}
