import AppKit
import SwiftUI

struct ContentView: View {
    let nowPlayingStore: NowPlayingStore
    let lyricsStore: LyricsStore

    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lyricAlignment") private var lyricAlignment: LyricAlignment = .leading
    @AppStorage("visibleLinesMode") private var visibleLinesMode: VisibleLinesMode = .all
    @AppStorage("compactMode") private var compactMode: Bool = false

    var body: some View {
        Group {
            if compactMode {
                compactBarView
                    .frame(minWidth: 380, idealWidth: 480, maxWidth: 680, minHeight: 56, maxHeight: 68)
            } else {
                fullLyricsView
                    .frame(minWidth: 320, minHeight: 400)
            }
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var fullLyricsView: some View {
        VStack(spacing: 0) {
            switch nowPlayingStore.status {
            case .nothingPlaying:
                stateView(
                    icon: "music.note.list",
                    title: "Nothing Playing",
                    subtitle: "Play a song in Spotify or Apple Music to see synced lyrics."
                )

            case .needsPermission(let source):
                permissionView(source: source)

            case .active(let playbackState):
                VStack(spacing: 12) {
                    HeaderView(
                        track: playbackState.track,
                        isPlaying: playbackState.isPlaying,
                        compactMode: $compactMode
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Divider()
                        .opacity(0.4)

                    lyricsBody(playbackState: playbackState)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var compactBarView: some View {
        HStack(spacing: 12) {
            switch nowPlayingStore.status {
            case .nothingPlaying:
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                Text("Nothing Playing")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()

            case .needsPermission(let source):
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text("Allow Automation for \(source.rawValue) in System Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()

            case .active(let playbackState):
                ArtworkView(url: playbackState.track.artworkURL, size: 32, cornerRadius: 6)
                compactLineText(playbackState: playbackState)
                Spacer(minLength: 8)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    compactMode = false
                }
            } label: {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand lyrics window")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func compactLineText(playbackState: PlaybackState) -> some View {
        switch lyricsStore.state {
        case .loaded(.synced(let lines)):
            TimelineView(.animation(minimumInterval: 0.2, paused: !playbackState.isPlaying)) { context in
                let position = playbackState.interpolatedPosition(at: context.date)
                let index = LRCParser.activeLineIndex(in: lines, at: position)
                let text = index.flatMap { lines[$0].text.isEmpty ? "♪" : lines[$0].text }
                    ?? "\(playbackState.track.title) — \(playbackState.track.artist)"

                Text(text)
                    .font(.system(size: min(fontSize, 20), weight: .semibold))
                    .lineLimit(1)
                    .id(index ?? -1)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        case .loaded(.instrumental):
            Text("\(playbackState.track.title) (Instrumental)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        default:
            Text("\(playbackState.track.title) — \(playbackState.track.artist)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func permissionView(source: MusicSource) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Automation Permission Needed")
                .font(.headline)
            Text("Allow Hum to control \(source.rawValue) in System Settings > Privacy & Security > Automation.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func lyricsBody(playbackState: PlaybackState) -> some View {
        switch lyricsStore.state {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Finding lyrics…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let content):
            switch content {
            case .synced(let lines):
                LyricsListView(
                    lines: lines,
                    playbackState: playbackState,
                    fontSize: fontSize,
                    alignment: lyricAlignment,
                    visibleLinesMode: visibleLinesMode,
                    onSeek: { position in
                        nowPlayingStore.seek(to: position)
                    }
                )

            case .plain(let text):
                ScrollView {
                    Text(text)
                        .font(.system(size: fontSize))
                        .multilineTextAlignment(lyricAlignment.textAlignment)
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: lyricAlignment.frameAlignment)
                        .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)

            case .instrumental:
                stateView(
                    icon: "pianokeys",
                    title: "Instrumental",
                    subtitle: "No lyrics for this track."
                )

            case .notFound:
                stateView(
                    icon: "text.magnifyingglass",
                    title: "No Lyrics Found",
                    subtitle: "LRCLIB doesn't have lyrics for this track yet."
                )
            }

        case .error(let message):
            stateView(
                icon: "wifi.exclamationmark",
                title: "Couldn't Load Lyrics",
                subtitle: message
            )
        }
    }

    private func stateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
