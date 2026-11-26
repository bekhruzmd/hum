import SwiftUI

@Observable
@MainActor
final class IslandModel {
    var geometry: IslandGeometry?
    var isExpanded = false
}

/// The island's SwiftUI content. The panel is sized by `IslandController`; this view draws the
/// black silhouette at the top center and animates between collapsed and expanded.
struct IslandView: View {
    let environment: AppEnvironment
    let model: IslandModel
    let onHover: (Bool) -> Void

    private var nowPlaying: NowPlayingStore { environment.nowPlaying }

    var body: some View {
        if let geometry = model.geometry, let state = nowPlaying.playbackState {
            let expanded = model.isExpanded
            let size = expanded
                ? CGSize(width: geometry.expandedFrame.width, height: geometry.expandedFrame.height)
                : geometry.collapsedSize
            ZStack(alignment: .top) {
                silhouette(expanded: expanded, geometry: geometry)
                    .shadow(color: .black.opacity(expanded || !geometry.hasNotch ? 0.35 : 0), radius: 12, y: 6)

                if expanded {
                    expandedContent(state: state, geometry: geometry)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else {
                    collapsedContent(state: state, geometry: geometry)
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onHover(perform: onHover)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.36, dampingFraction: 0.8), value: expanded)
            .environment(\.colorScheme, .dark)
        }
    }

    /// Wraps the notch on notched displays; a free-floating rounded pill elsewhere.
    @ViewBuilder
    private func silhouette(expanded: Bool, geometry: IslandGeometry) -> some View {
        if geometry.hasNotch {
            IslandShape(shoulder: expanded ? 16 : 7, bottomRadius: expanded ? 30 : 11).fill(.black)
        } else {
            RoundedRectangle(cornerRadius: expanded ? 28 : geometry.collapsedSize.height / 2, style: .continuous)
                .fill(.black)
        }
    }

    // MARK: Collapsed

    private func collapsedContent(state: PlaybackState, geometry: IslandGeometry) -> some View {
        let coverSize = geometry.hasNotch ? max(16, geometry.notchHeight - 12) : 20
        return HStack(spacing: 8) {
            ArtworkView(image: nowPlaying.artworkImage, size: coverSize, cornerRadius: 5)
            if geometry.hasNotch {
                Spacer(minLength: geometry.notchWidth)
            } else {
                Text(state.track.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            PlaybackBars(isPlaying: state.isPlaying, color: nowPlaying.palette.highlight, barWidth: 2.5, height: 12)
        }
        .padding(.horizontal, geometry.hasNotch ? 16 : 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing: \(state.track.title) by \(state.track.artist)")
    }

    // MARK: Expanded

    private func expandedContent(state: PlaybackState, geometry: IslandGeometry) -> some View {
        VStack(spacing: 10) {
            if geometry.hasNotch {
                Color.clear.frame(height: geometry.notchHeight - 4)
            }
            HStack(spacing: 12) {
                Button {
                    environment.windows.showLyrics()
                } label: {
                    ArtworkView(image: nowPlaying.artworkImage, size: 58, cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .help("Open the lyrics window")
                .accessibilityLabel("Open the lyrics window")

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(state.track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .lineLimit(1)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 6)

                TransportControls(nowPlaying: nowPlaying, isPlaying: state.isPlaying)
            }

            if environment.settings.islandShowsLyrics {
                IslandLyricLine(environment: environment, state: state)
                    .frame(height: 34)
            }

            Scrubber(state: state, tint: nowPlaying.palette.highlight) { nowPlaying.seek(to: $0) }
        }
        .padding(.horizontal, geometry.hasNotch ? 34 : 20)
        .padding(.top, geometry.hasNotch ? 0 : 14)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

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
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The current lyric line in the user's effect, sized for the island.
private struct IslandLyricLine: View {
    let environment: AppEnvironment
    let state: PlaybackState

    var body: some View {
        let lines = environment.lyrics.timedLines
        TimelineView(.animation(minimumInterval: 0.1, paused: !state.isPlaying)) { timeline in
            let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
            Group {
                if let index {
                    LiveLyricEffect(
                        kind: environment.settings.lyricEffect == .bigWords ? .karaokeFill : environment.settings.lyricEffect,
                        line: lines[index],
                        palette: environment.nowPlaying.palette,
                        fontSize: 14,
                        alignment: .center,
                        isPlaying: state.isPlaying,
                        lyricTime: { environment.lyricTime(state, at: $0) }
                    )
                } else {
                    Text(lines.isEmpty ? state.track.album : "♪")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .id(index ?? -1)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: index)
        }
        .clipped()
    }
}
