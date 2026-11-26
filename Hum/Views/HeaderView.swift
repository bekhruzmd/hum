import SwiftUI

struct HeaderView: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            artworkView
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let url = track.artworkURL {
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
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
