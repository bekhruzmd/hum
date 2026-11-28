import SwiftUI

enum IslandPage: Int, CaseIterable {
    case player
    case lyrics
}

@Observable
@MainActor
final class IslandModel {
    var geometry: IslandGeometry?
    var isExpanded = false
    /// Pointer is resting on the closed island (waiting for the hover delay, or click mode).
    var isHinting = false
    var size: IslandSize = .regular
    var motion: IslandMotion = .smooth
    var page: IslandPage = .player
    /// +1 when moving to a later page, -1 when moving back; drives the slide direction.
    var pageDirection: CGFloat = 1
}

/// What the island asks its controller to do.
struct IslandInteractions {
    var tap: () -> Void
    /// Pull down (true) to open, push up (false) to close.
    var pull: (Bool) -> Void
    var selectPage: (IslandPage) -> Void
}

/// The island, drawn at the top center of a fixed-size, transparent panel.
///
/// Closed, it is solid black and reads as part of the notch. Open, it springs down out of the
/// notch: solid black where it meets the notch, fading into translucent glass, with the content
/// revealed by the growing shape and sharpening in from a slight blur. Because the panel never
/// resizes, every open and close is a plain spring that can be interrupted and reversed.
struct IslandView: View {
    let environment: AppEnvironment
    let model: IslandModel
    let interactions: IslandInteractions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var nowPlaying: NowPlayingStore { environment.nowPlaying }

    var body: some View {
        if let geometry = model.geometry, let state = nowPlaying.playbackState {
            let open = model.isExpanded
            let openSize = geometry.expandedSize(content: model.size.expanded)
            let size = open ? openSize : geometry.collapsedSize
            ZStack(alignment: .top) {
                background(open: open, geometry: geometry)

                ZStack(alignment: .top) {
                    if open {
                        IslandOpenContent(environment: environment, model: model, interactions: interactions,
                                          state: state, geometry: geometry)
                            .frame(width: openSize.width, height: openSize.height, alignment: .top)
                            .transition(revealTransition)
                    } else {
                        IslandClosedContent(environment: environment, model: model, state: state, geometry: geometry)
                            .frame(width: geometry.collapsedSize.width, height: geometry.collapsedSize.height)
                            .transition(.opacity.animation(.easeOut(duration: 0.16).delay(0.1)))
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .top)
                .mask(shape(open: open, geometry: geometry))
            }
            .frame(width: size.width, height: size.height)
            .contentShape(shape(open: open, geometry: geometry))
            .onTapGesture { if !open { interactions.tap() } }
            .simultaneousGesture(pullGesture(open: open))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : (open ? model.motion.open : model.motion.close), value: open)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: model.isHinting)
            .environment(\.colorScheme, .dark)
        }
    }

    // MARK: Material

    private func shape(open: Bool, geometry: IslandGeometry) -> AnyShape {
        if geometry.hasNotch {
            return AnyShape(IslandShape(shoulder: open ? 10 : 7, bottomRadius: open ? 26 : 11))
        }
        return AnyShape(RoundedRectangle(cornerRadius: open ? 24 : geometry.collapsedSize.height / 2, style: .continuous))
    }

    /// Solid black where it meets the notch, frosted glass below. Closed, it is solid black.
    @ViewBuilder
    private func background(open: Bool, geometry: IslandGeometry) -> some View {
        let shape = shape(open: open, geometry: geometry)
        let band = geometry.hasNotch ? geometry.notchHeight : 0
        let height = geometry.expandedSize(content: model.size.expanded).height
        let bandStop = min(0.6, band / max(1, height))
        let material = environment.settings.surfaceMaterial.resolved(reduceTransparency: reduceTransparency)
        ZStack {
            SurfaceBackground(material: material, shape: shape, darkening: material == .liquidGlass ? 0.25 : 0.5)
            if material != .solid {
                // Solid black where the island meets the notch, easing into the material below.
                shape.fill(LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: bandStop),
                    .init(color: .black.opacity(material == .liquidGlass ? 0.25 : 0.35), location: min(1, bandStop + 0.25)),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom))
                // Light catching the lower edge.
                shape.stroke(LinearGradient(colors: [.clear, .clear, .white.opacity(0.16)],
                                            startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            // Closed: solid black, indistinguishable from the notch.
            shape.fill(.black).opacity(open ? 0 : 1)
        }
        .shadow(color: .black.opacity(open ? 0.35 : (geometry.hasNotch ? 0 : 0.3)), radius: open ? 22 : 8, y: open ? 10 : 3)
    }

    /// Vertical drags pull the island open or push it closed; horizontal drags are left to the scrubber.
    private func pullGesture(open: Bool) -> some Gesture {
        DragGesture(minimumDistance: 8)
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
                .animation(model.motion.open.delay(0.05)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        )
    }
}

/// Reveal for the open island's content: sharpens in from a slight blur while settling down
/// toward its place, as if it were pulled out of the notch.
private struct IslandReveal: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 5)
            .scaleEffect(0.96 + 0.04 * progress, anchor: .top)
            .offset(y: (1 - progress) * -10)
    }
}

// MARK: - Closed

private struct IslandClosedContent: View {
    let environment: AppEnvironment
    let model: IslandModel
    let state: PlaybackState
    let geometry: IslandGeometry

    var body: some View {
        let nowPlaying = environment.nowPlaying
        let coverSize = geometry.hasNotch ? max(16, geometry.notchHeight - 12) : 20
        let hint = model.isHinting
        HStack(spacing: 8) {
            ArtworkView(image: nowPlaying.artworkImage, size: coverSize, cornerRadius: 5)
                .scaleEffect(hint ? 1.1 : 1)
            if geometry.hasNotch {
                Spacer(minLength: geometry.notchWidth)
            } else {
                Text(state.track.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            if environment.settings.islandShowsBars {
                PlaybackBars(isPlaying: state.isPlaying && environment.renderGate.canAnimate,
                             color: nowPlaying.palette.highlight, barWidth: 2.5, height: 12)
                    .scaleEffect(hint ? 1.12 : 1)
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 16 : 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing: \(state.track.title) by \(state.track.artist)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Open

private struct IslandOpenContent: View {
    let environment: AppEnvironment
    let model: IslandModel
    let interactions: IslandInteractions
    let state: PlaybackState
    let geometry: IslandGeometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsLyricsPage: Bool { environment.settings.islandShowsLyrics }

    var body: some View {
        VStack(spacing: 0) {
            band
            Group {
                switch showsLyricsPage ? model.page : .player {
                case .player:
                    IslandPlayerPage(environment: environment, state: state, size: model.size)
                        .transition(pageTransition)
                case .lyrics:
                    IslandLyricsPage(environment: environment, state: state, size: model.size)
                        .transition(pageTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 1), value: model.page)
        }
    }

    /// The strip beside the notch: page dots on the left, expand on the right.
    private var band: some View {
        HStack(spacing: 0) {
            if showsLyricsPage {
                IslandPageDots(page: model.page, select: interactions.selectPage)
            }
            Spacer(minLength: geometry.hasNotch ? geometry.notchWidth + 16 : 8)
            Button {
                environment.windows.showLyrics()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.12), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(MusicBarButtonStyle())
            .help("Open the lyrics window")
            .accessibilityLabel("Open the lyrics window")
        }
        .padding(.horizontal, 22)
        .frame(height: geometry.hasNotch ? geometry.notchHeight : 34)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = model.pageDirection > 0
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

private struct IslandPageDots: View {
    let page: IslandPage
    let select: (IslandPage) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(IslandPage.allCases, id: \.rawValue) { item in
                Button { select(item) } label: {
                    Capsule()
                        .fill(.white.opacity(item == page ? 0.95 : 0.35))
                        .frame(width: item == page ? 16 : 6, height: 6)
                        .frame(height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item == .player ? "Player" : "Lyrics")
                .accessibilityAddTraits(item == page ? [.isSelected] : [])
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 1), value: page)
    }
}

private struct IslandPlayerPage: View {
    let environment: AppEnvironment
    let state: PlaybackState
    let size: IslandSize

    var body: some View {
        let nowPlaying = environment.nowPlaying
        let transport = size.transportSizes
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ArtworkView(image: nowPlaying.artworkImage, size: size.artworkSize, cornerRadius: size.artworkSize * 0.2)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.track.title)
                        .font(.system(size: size.titleSize, weight: .bold))
                        .foregroundStyle(.white)
                    Text(state.track.artist)
                        .font(.system(size: size.titleSize - 2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .accessibilityElement(children: .combine)
                if environment.settings.islandShowsBars {
                    PlaybackBars(isPlaying: state.isPlaying && environment.renderGate.canAnimate,
                                 color: .white.opacity(0.85), barWidth: 2.5, height: 16)
                }
            }

            IslandProgress(state: state, animate: environment.renderGate.canAnimate) { nowPlaying.seek(to: $0) }
                .padding(.top, 12)

            ZStack {
                HStack(spacing: size == .compact ? 34 : 44) {
                    control("backward.fill", label: "Previous track", size: transport.skip) { nowPlaying.previousTrack() }
                    control(state.isPlaying ? "pause.fill" : "play.fill", label: state.isPlaying ? "Pause" : "Play",
                            size: transport.play) { nowPlaying.playPause() }
                    control("forward.fill", label: "Next track", size: transport.skip) { nowPlaying.nextTrack() }
                }
                HStack {
                    Spacer()
                    control("laptopcomputer", label: "Open \(state.track.player.displayName)", size: transport.skip - 4) {
                        environment.musicBarActions().openPlayer()
                    }
                    .opacity(0.75)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func control(_ symbol: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size + 14, height: size + 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusicBarButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Elapsed time, a thin bar you can drag or click, and the track length.
private struct IslandProgress: View {
    let state: PlaybackState
    let animate: Bool
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var isHovered = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !animate || !state.isPlaying || dragFraction != nil)) { timeline in
            let duration = max(1, state.track.duration)
            let fraction = dragFraction ?? min(1, state.interpolatedPosition(at: timeline.date) / duration)
            HStack(spacing: 10) {
                Text(Scrubber.format(fraction * duration))
                    .frame(width: 34, alignment: .leading)
                GeometryReader { proxy in
                    let active = dragFraction != nil || isHovered
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white.opacity(0.9)).frame(width: max(0, proxy.size.width * fraction))
                    }
                    .frame(height: active ? 6 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = min(1, max(0, value.location.x / max(1, proxy.size.width)))
                            }
                            .onEnded { _ in
                                if let dragFraction { onSeek(dragFraction * duration) }
                                dragFraction = nil
                            }
                    )
                    .onHover { isHovered = $0 }
                    .animation(.spring(response: 0.2, dampingFraction: 1), value: active)
                }
                .frame(height: 16)
                Text(Scrubber.format(duration))
                    .frame(width: 34, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.62))
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Scrubber.format(state.interpolatedPosition())) of \(Scrubber.format(state.track.duration))")
        .accessibilityAdjustableAction { direction in
            onSeek(max(0, state.interpolatedPosition() + (direction == .increment ? 10 : -10)))
        }
    }
}

/// The current line in the user's lyric effect, large, with the next line waiting below.
private struct IslandLyricsPage: View {
    let environment: AppEnvironment
    let state: PlaybackState
    let size: IslandSize

    var body: some View {
        let lines = environment.lyrics.timedLines
        let animate = state.isPlaying && environment.renderGate.canAnimate
        let fontSize: CGFloat = size == .large ? 20 : (size == .compact ? 16 : 18)
        TimelineView(.animation(minimumInterval: 0.1, paused: !animate)) { timeline in
            let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
            VStack(spacing: 8) {
                if let index {
                    LiveLyricEffect(
                        kind: LiveLyricEffect.singleRow(environment.settings.lyricEffect),
                        line: lines[index],
                        palette: environment.nowPlaying.palette,
                        fontSize: fontSize,
                        alignment: .center,
                        isPlaying: animate,
                        lyricTime: { environment.lyricTime(state, at: $0) }
                    )
                    .id(index)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    if index + 1 < lines.count {
                        Text(lines[index + 1].displayText)
                            .font(.system(size: fontSize * 0.72, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                            .id("next-\(index)")
                            .transition(.opacity)
                    }
                } else {
                    Text(lines.isEmpty ? "No synced lyrics for this song" : "♪")
                        .font(.system(size: fontSize * 0.8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 1), value: index)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 14)
        .clipped()
    }
}
