import SwiftUI

/// Actions exist only in Hum. The screensaver renders the same live card without accepting input.
struct MusicBarActions {
    var playPause: () -> Void
    var previous: () -> Void
    var next: () -> Void
    var seek: (TimeInterval) -> Void
    var shuffle: () -> Void
    var openPlayer: () -> Void
    var playerName: String
}

/// Compact glass player, shared with the saver so artwork, timing and typography stay identical.
struct MusicBar: View {
    static let width: CGFloat = 320
    static let cardHeight: CGFloat = 146
    static let expandedHeight: CGFloat = 466
    static let motion = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.28)

    let data: CinematicSceneData
    let animate: Bool
    @Binding var isArtworkExpanded: Bool
    var actions: MusicBarActions? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var artworkSpace
    @State private var isHovered = false

    private var identity: String {
        [data.track?.title, data.track?.artist, data.track?.album].compactMap { $0 }.joined(separator: "\u{1F}")
    }

    var body: some View {
        VStack(spacing: 14) {
            if isArtworkExpanded {
                artworkButton(size: 306, expanded: true)
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
            VStack(spacing: 8) {
                HStack(spacing: 11) {
                    if isArtworkExpanded {
                        Button(action: toggleArtwork) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(MusicBarButtonStyle())
                        .help("Collapse artwork")
                        .accessibilityLabel("Collapse artwork")
                    } else {
                        artworkButton(size: 42, expanded: false)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(data.track?.title ?? "Nothing playing")
                            .font(.system(size: 13, weight: .semibold))
                        Text(data.track?.artist ?? "Play music in Spotify or Music")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: identity)
                    PlaybackBars(isPlaying: data.isPlaying && animate, color: .white.opacity(0.85), barWidth: 2, height: 13)
                        .frame(width: 24)
                }
                .frame(height: 42)

                MusicBarProgress(identity: identity, duration: data.track?.duration ?? 0,
                                 isPlaying: data.isPlaying, animate: animate,
                                 position: data.playbackPosition, onSeek: actions?.seek)

                HStack(spacing: 0) {
                    control("shuffle", label: data.isShuffling == true ? "Turn shuffle off" : "Turn shuffle on",
                            size: 13, action: data.isShuffling == nil ? nil : actions?.shuffle)
                        .foregroundStyle(.white.opacity(data.isShuffling == nil ? 0.25 : data.isShuffling == true ? 1 : 0.5))
                        .overlay(alignment: .bottom) {
                            if data.isShuffling == true { Circle().fill(.white).frame(width: 3, height: 3).offset(y: -1) }
                        }
                    Spacer(minLength: 0)
                    control("backward.fill", label: "Previous track", size: 17, action: actions?.previous)
                    Spacer(minLength: 0)
                    control(data.isPlaying ? "pause.fill" : "play.fill", label: data.isPlaying ? "Pause" : "Play",
                            size: 21, action: actions?.playPause)
                    Spacer(minLength: 0)
                    control("forward.fill", label: "Next track", size: 17, action: actions?.next)
                    Spacer(minLength: 0)
                    control("laptopcomputer", label: "Open \(actions?.playerName ?? "music player")", size: 14, action: actions?.openPlayer)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(height: 34)
            }
            .padding(.horizontal, 14)
            .frame(width: Self.width, height: Self.cardHeight)
            .background {
                let shape = RoundedRectangle(cornerRadius: 21, style: .continuous)
                SurfaceBackground(material: data.surfaceMaterial, shape: shape, darkening: 0.38)
                if data.surfaceMaterial.resolved(reduceTransparency: reduceTransparency) == .frosted {
                    shape.fill(LinearGradient(colors: [.white.opacity(0.08), .clear, .white.opacity(0.025)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(isHovered ? 0.8 : 0.62), .white.opacity(0.18), .white.opacity(0.4)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                shape.inset(by: 2).strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.16)) { isHovered = actions != nil && hovering }
            }
        }
        .frame(width: Self.width)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(actions != nil)
        .accessibilityElement(children: actions == nil ? .ignore : .contain)
        .accessibilityLabel(actions == nil
            ? "\(data.track?.title ?? "Nothing playing"), \(data.track?.artist ?? ""). \(data.isPlaying ? "Playing" : "Paused")"
            : "Music player")
        .onChange(of: data.track == nil) { _, empty in if empty { isArtworkExpanded = false } }
    }

    private func toggleArtwork() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Self.motion) { isArtworkExpanded.toggle() }
    }

    private func artworkButton(size: CGFloat, expanded: Bool) -> some View {
        Button(action: toggleArtwork) {
            Group {
                if let artwork = data.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.white.opacity(0.06))
                        .overlay(Image(systemName: "music.note").font(.system(size: size * 0.35)).foregroundStyle(.white.opacity(0.4)))
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 13 : 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: expanded ? 13 : 7).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .matchedGeometryEffect(id: "artwork", in: artworkSpace, properties: reduceMotion ? [] : .frame)
            .contentShape(Rectangle())
        }
        .buttonStyle(MusicBarButtonStyle())
        .help(expanded ? "Collapse artwork" : "Expand artwork")
        .accessibilityLabel(expanded ? "Collapse artwork" : "Expand artwork")
    }

    @ViewBuilder
    private func control(_ symbol: String, label: String, size: CGFloat, action: (() -> Void)?) -> some View {
        let icon = Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace.offUp))
            .animation(.easeOut(duration: 0.16), value: symbol)
            .frame(width: 36, height: 34)
            .contentShape(Rectangle())
        if let action {
            Button(action: action) { icon }
                .buttonStyle(MusicBarButtonStyle())
                .help(label)
                .accessibilityLabel(label)
        } else {
            icon.accessibilityHidden(true)
        }
    }
}

struct MusicBarButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.16), value: configuration.isPressed)
    }
}

private struct MusicBarProgress: View {
    let identity: String
    let duration: TimeInterval
    let isPlaying: Bool
    let animate: Bool
    let position: (Date) -> TimeInterval
    let onSeek: ((TimeInterval) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragFraction: Double?
    @State private var dragTrack: String?
    @State private var isHovered = false

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30, paused: !animate || !isPlaying || dragFraction != nil)) { timeline in
            let total = duration.isFinite ? max(0, duration) : 0
            let elapsed = min(total, max(0, position(timeline.date)))
            let fraction = dragFraction ?? (total > 0 ? elapsed / total : 0)
            HStack(spacing: 7) {
                Text(Self.format(fraction * total)).frame(width: 29, alignment: .leading)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white.opacity(0.92)).frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: dragFraction != nil || isHovered ? 5 : 3)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard onSeek != nil, total > 0 else { return }
                            if dragTrack == nil { dragTrack = identity }
                            guard dragTrack == identity else { return }
                            dragFraction = min(1, max(0, value.location.x / max(1, proxy.size.width)))
                        }
                        .onEnded { _ in
                            if dragTrack == identity, let dragFraction { onSeek?(dragFraction * total) }
                            dragFraction = nil
                            dragTrack = nil
                        })
                    .onHover { isHovered = onSeek != nil && $0 }
                }
                Text("−" + Self.format((1 - fraction) * total)).frame(width: 35, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
            .frame(height: 18)
        }
        .onChange(of: identity) { _, _ in dragFraction = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Self.format(position(Date()))) of \(Self.format(duration))")
        .accessibilityAdjustableAction { direction in
            guard duration > 0 else { return }
            onSeek?(min(duration, max(0, position(Date()) + (direction == .increment ? 10 : -10))))
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? Int(min(359_999, max(0, seconds))) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
