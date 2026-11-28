import SwiftUI

@Observable
@MainActor
final class IslandModel {
    var geometry: IslandGeometry?
    var isExpanded = false
    /// Pointer is resting on the closed island (waiting for the hover delay, or click mode).
    var isHinting = false
    var size: IslandSize = .regular
    var motion: IslandMotion = .smooth
}

/// What the island asks its controller to do.
struct IslandInteractions {
    var hover: (Bool) -> Void
    var tap: () -> Void
    /// Pull down (true) to open, push up (false) to close.
    var pull: (Bool) -> Void
}

/// The island's SwiftUI content. The panel is sized by `IslandController`; this view draws the
/// black silhouette at the top center and morphs it between closed and open.
///
/// Opening: the silhouette springs out of the notch and the content, laid out at its final
/// size, is revealed by the growing shape, then sharpens in from a slight blur. Closing: the
/// content fades quickly and the shape settles back without overshoot.
struct IslandView: View {
    let environment: AppEnvironment
    let model: IslandModel
    let interactions: IslandInteractions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nowPlaying: NowPlayingStore { environment.nowPlaying }

    var body: some View {
        if let geometry = model.geometry, let state = nowPlaying.playbackState {
            let open = model.isExpanded
            let openSize = geometry.expandedSize(content: model.size.expanded)
            let size = open ? openSize : geometry.collapsedSize
            ZStack(alignment: .top) {
                silhouette(open: open, geometry: geometry)
                    .shadow(color: .black.opacity(open || !geometry.hasNotch ? 0.4 : 0), radius: open ? 18 : 8, y: open ? 8 : 3)

                ZStack(alignment: .top) {
                    if open {
                        expandedContent(state: state, geometry: geometry)
                            .frame(width: openSize.width, height: openSize.height, alignment: .top)
                            .transition(revealTransition)
                    } else {
                        collapsedContent(state: state, geometry: geometry)
                            .frame(width: geometry.collapsedSize.width, height: geometry.collapsedSize.height)
                            .transition(.opacity.animation(.easeOut(duration: 0.18).delay(open ? 0 : 0.12)))
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .top)
                .mask(silhouette(open: open, geometry: geometry))
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onHover(perform: interactions.hover)
            .onTapGesture { if !open { interactions.tap() } }
            .simultaneousGesture(pullGesture(open: open))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : (open ? model.motion.open : model.motion.close), value: open)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: model.isHinting)
            .environment(\.colorScheme, .dark)
        }
    }

    /// Vertical drags pull the island open or push it closed; horizontal drags are left to the scrubber.
    private func pullGesture(open: Bool) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let dy = value.translation.height, dx = value.translation.width
                guard abs(dy) > abs(dx) * 1.4 else { return }
                if !open && dy > 10 { interactions.pull(true) }
                if open && dy < -24 { interactions.pull(false) }
            }
    }

    private var revealTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: IslandReveal(progress: 0), identity: IslandReveal(progress: 1))
                .animation(model.motion.open.delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }

    /// Wraps the notch on notched displays; a free-floating rounded pill elsewhere.
    @ViewBuilder
    private func silhouette(open: Bool, geometry: IslandGeometry) -> some View {
        if geometry.hasNotch {
            IslandShape(shoulder: open ? 18 : 7, bottomRadius: open ? 32 : 11).fill(.black)
        } else {
            RoundedRectangle(cornerRadius: open ? 30 : geometry.collapsedSize.height / 2, style: .continuous)
                .fill(.black)
        }
    }

    // MARK: Closed

    private func collapsedContent(state: PlaybackState, geometry: IslandGeometry) -> some View {
        let coverSize = geometry.hasNotch ? max(16, geometry.notchHeight - 12) : 20
        let hint = model.isHinting
        return HStack(spacing: 8) {
            ArtworkView(image: nowPlaying.artworkImage, size: coverSize, cornerRadius: 5)
                .scaleEffect(hint ? 1.12 : 1)
            if geometry.hasNotch {
                Spacer(minLength: geometry.notchWidth)
            } else {
                Text(state.track.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            if environment.settings.islandShowsBars {
                PlaybackBars(isPlaying: state.isPlaying && environment.renderGate.canAnimate,
                             color: nowPlaying.palette.highlight, barWidth: 2.5, height: 12)
                    .scaleEffect(hint ? 1.15 : 1)
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 16 : 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing: \(state.track.title) by \(state.track.artist)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { interactions.tap() }
    }

    // MARK: Open

    private func expandedContent(state: PlaybackState, geometry: IslandGeometry) -> some View {
        let size = model.size
        let large = size == .large
        return VStack(spacing: large ? 12 : 9) {
            if geometry.hasNotch {
                Color.clear.frame(height: geometry.notchHeight - 4)
            }
            HStack(spacing: 12) {
                Button {
                    environment.windows.showLyrics()
                } label: {
                    ArtworkView(image: nowPlaying.artworkImage, size: size.artworkSize, cornerRadius: large ? 13 : 10)
                        .shadow(color: nowPlaying.palette.highlight.opacity(0.35), radius: 10, y: 3)
                }
                .buttonStyle(MusicBarButtonStyle())
                .help("Open the lyrics window")
                .accessibilityLabel("Open the lyrics window")

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.track.title)
                        .font(.system(size: large ? 16 : 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(state.track.artist)
                        .font(.system(size: large ? 13 : 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .lineLimit(1)
                .contentTransition(.opacity)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 6)

                TransportControls(nowPlaying: nowPlaying, isPlaying: state.isPlaying)
            }

            if environment.settings.islandShowsLyrics && size != .compact {
                IslandLyricLine(environment: environment, state: state, fontSize: large ? 16 : 14)
                    .frame(height: large ? 44 : 34)
            }

            Scrubber(state: state, tint: nowPlaying.palette.highlight, animate: environment.renderGate.canAnimate) {
                nowPlaying.seek(to: $0)
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 36 : 22)
        .padding(.top, geometry.hasNotch ? 0 : 14)
        .padding(.bottom, 12)
    }
}

/// Reveal for the open island's content: sharpens in from a slight blur while settling down.
private struct IslandReveal: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 6)
            .scaleEffect(0.94 + 0.06 * progress, anchor: .top)
            .offset(y: (1 - progress) * -8)
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
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusicBarButtonStyle())
        .accessibilityLabel(label)
    }
}

/// The current lyric line in the user's effect, sized for the island.
private struct IslandLyricLine: View {
    let environment: AppEnvironment
    let state: PlaybackState
    let fontSize: CGFloat

    var body: some View {
        let lines = environment.lyrics.timedLines
        TimelineView(.animation(minimumInterval: 0.1, paused: !(state.isPlaying && environment.renderGate.canAnimate))) { timeline in
            let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
            Group {
                if let index {
                    LiveLyricEffect(
                        kind: LiveLyricEffect.singleRow(environment.settings.lyricEffect),
                        line: lines[index],
                        palette: environment.nowPlaying.palette,
                        fontSize: fontSize,
                        alignment: .center,
                        isPlaying: state.isPlaying && environment.renderGate.canAnimate,
                        lyricTime: { environment.lyricTime(state, at: $0) }
                    )
                } else {
                    Text(lines.isEmpty ? state.track.album : "♪")
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
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
