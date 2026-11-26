import SwiftUI

struct LyricsWindowView: View {
    let environment: AppEnvironment

    private var settings: SettingsStore { environment.settings }
    private var nowPlaying: NowPlayingStore { environment.nowPlaying }
    private var lyrics: LyricsStore { environment.lyrics }

    var body: some View {
        Group {
            if settings.compactMode {
                compactBar
                    .frame(minWidth: 380, idealWidth: 480, maxWidth: 680, minHeight: 56, maxHeight: 68)
            } else {
                fullView
                    .frame(minWidth: 320, minHeight: 400)
            }
        }
        .background { AlbumBackground(palette: nowPlaying.palette, tinted: settings.tintWithAlbumColors) }
    }

    // MARK: Full

    @ViewBuilder
    private var fullView: some View {
        switch nowPlaying.status {
        case .nothingPlaying:
            StateView(
                icon: "music.note.list",
                title: "Nothing Playing",
                message: "Play a song in Spotify or Apple Music to see synced lyrics."
            )
        case .needsPermission(let player):
            PermissionView(player: player)
        case .active(let state):
            VStack(spacing: 12) {
                HeaderView(
                    track: state.track,
                    artwork: nowPlaying.artworkImage,
                    isPlaying: state.isPlaying,
                    onCompact: { setCompact(true) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 28)

                Divider().opacity(0.4)

                lyricsBody(state: state)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func lyricsBody(state: PlaybackState) -> some View {
        switch lyrics.state {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Finding lyrics…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(.synced(let lines)):
            LyricsListView(
                lines: lines,
                playbackState: state,
                fontSize: settings.fontSize,
                alignment: settings.lyricAlignment,
                visibleLinesMode: settings.visibleLinesMode,
                onSeek: { nowPlaying.seek(to: $0) }
            )

        case .loaded(.plain(let text)):
            ScrollView {
                Text(text)
                    .font(.system(size: settings.fontSize))
                    .multilineTextAlignment(settings.lyricAlignment.textAlignment)
                    .foregroundStyle(.primary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: settings.lyricAlignment.frameAlignment)
                    .padding(.vertical, 12)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)

        case .loaded(.instrumental):
            StateView(icon: "pianokeys", title: "Instrumental", message: "No lyrics for this track.")

        case .loaded(.notFound):
            StateView(
                icon: "text.magnifyingglass",
                title: "No Lyrics Found",
                message: "LRCLIB doesn't have lyrics for this track yet."
            )

        case .error(let message):
            StateView(icon: "wifi.exclamationmark", title: "Couldn't Load Lyrics", message: message)
        }
    }

    // MARK: Compact

    private var compactBar: some View {
        HStack(spacing: 12) {
            switch nowPlaying.status {
            case .nothingPlaying:
                Image(systemName: "music.note").foregroundStyle(.secondary)
                Text("Nothing Playing").font(.callout).foregroundStyle(.secondary)
                Spacer()
            case .needsPermission(let player):
                Image(systemName: "lock.shield").foregroundStyle(.secondary)
                Text("Allow Automation for \(player.displayName) in System Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            case .active(let state):
                ArtworkView(image: nowPlaying.artworkImage, size: 32, cornerRadius: 6)
                compactLine(state: state)
                Spacer(minLength: 8)
            }

            Button { setCompact(false) } label: {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand lyrics window")
            .accessibilityLabel("Expand lyrics window")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func compactLine(state: PlaybackState) -> some View {
        let fallback = "\(state.track.title) — \(state.track.artist)"
        switch lyrics.state {
        case .loaded(.synced(let lines)):
            TimelineView(.animation(minimumInterval: 0.2, paused: !state.isPlaying)) { context in
                let index = LRCParser.activeLineIndex(in: lines, at: state.interpolatedPosition(at: context.date))
                let text = index.map { lines[$0].displayText } ?? fallback
                Text(text)
                    .font(.system(size: min(settings.fontSize, 20), weight: .semibold))
                    .lineLimit(1)
                    .id(index ?? -1)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        case .loaded(.instrumental):
            Text("\(state.track.title) (Instrumental)")
                .font(.callout).foregroundStyle(.secondary).lineLimit(1)
        default:
            Text(fallback)
                .font(.callout).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func setCompact(_ compact: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.compactMode = compact
        }
    }
}

/// Translucent material, optionally washed with the album's colors.
struct AlbumBackground: View {
    let palette: AlbumPalette
    let tinted: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if tinted {
                LinearGradient(
                    colors: [palette.primary, palette.secondary, palette.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.35)
                .animation(.easeInOut(duration: 0.8), value: palette)
            }
        }
        .ignoresSafeArea()
    }
}
