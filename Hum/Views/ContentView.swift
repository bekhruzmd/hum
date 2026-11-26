import AppKit
import SwiftUI

struct ContentView: View {
    let nowPlayingStore: NowPlayingStore
    let lyricsStore: LyricsStore

    var body: some View {
        VStack(spacing: 0) {
            switch nowPlayingStore.status {
            case .nothingPlaying:
                stateView(
                    icon: "music.note.list",
                    title: "Nothing Playing",
                    subtitle: "Play a song in Spotify or Apple Music to see synced lyrics."
                )

            case .needsPermission(let source):
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

            case .active(let playbackState):
                VStack(spacing: 12) {
                    HeaderView(
                        track: playbackState.track,
                        isPlaying: playbackState.isPlaying
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
        .frame(minWidth: 320, minHeight: 400)
        .background(.ultraThinMaterial)
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
                LyricsListView(lines: lines, playbackState: playbackState)

            case .plain(let text):
                ScrollView {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
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
