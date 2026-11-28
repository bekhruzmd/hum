import SwiftUI

struct LyricsWindowView: View {
    let environment: AppEnvironment

    private var settings: SettingsStore { environment.settings }
    private var nowPlaying: NowPlayingStore { environment.nowPlaying }
    private var lyrics: LyricsStore { environment.lyrics }

    @State private var isHovering = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isDropTargeted = false
    @State private var toast: HumToast.Message?

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
        .background {
            AlbumBackground(
                palette: nowPlaying.palette,
                tinted: settings.tintWithAlbumColors,
                animated: nowPlaying.isPlaying && environment.renderGate.canAnimate && environment.windows.canRenderLyrics
            )
        }
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
                    offset: environment.offsets.offset(for: state.track),
                    onCompact: { setCompact(true) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 28)

                Divider().opacity(0.4)

                lyricsBody(state: state)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .overlay(alignment: .bottom) {
                if isHovering {
                    ControlBar(nowPlaying: nowPlaying, state: state, animate: environment.renderGate.canAnimate && environment.windows.canRenderLyrics,
                               material: settings.surfaceMaterial,
                               hint: { action in
                                   action == .playPause ? "Space" : environment.hotkeyStore.bindings[action]?.displayString
                               })
                        .padding(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background { PlaybackShortcuts(nowPlaying: nowPlaying, onClose: { environment.windows.hideLyrics() }) }
            .dropDestination(for: URL.self) { urls, _ in
                importLyrics(from: urls)
            } isTargeted: { isDropTargeted = $0 }
            .overlay { if isDropTargeted { DropHighlight(label: "Drop to use these lyrics") } }
            .overlay(alignment: .top) {
                if let toast {
                    HumToast(message: toast)
                        .padding(.top, 84)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 1), value: toast)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .onContinuousHover { phase in
                switch phase {
                case .active: showControls()
                case .ended: hideControls(after: .milliseconds(300))
                }
            }
        }
    }

    /// Uses a dropped .lrc or .txt file as this song's lyrics, and confirms with a toast.
    private func importLyrics(from urls: [URL]) -> Bool {
        guard let url = urls.first(where: LyricsImporter.canImport) else {
            show(HumToast.Message(text: "Drop a .lrc or .txt lyrics file", symbol: "exclamationmark.circle"))
            return false
        }
        guard let content = LyricsImporter.content(from: url) else {
            show(HumToast.Message(text: "Couldn't read those lyrics", symbol: "exclamationmark.circle"))
            return false
        }
        lyrics.override(with: content)
        if case .synced = content {
            show(HumToast.Message(text: "Synced lyrics added", symbol: "checkmark.circle.fill"))
        } else {
            show(HumToast.Message(text: "Lyrics added (not timed)", symbol: "checkmark.circle.fill"))
        }
        return true
    }

    private func show(_ message: HumToast.Message) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { toast = nil }
        }
    }

    /// Reveal the control bar on pointer movement; hide it after a few still seconds.
    private func showControls() {
        if !isHovering {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isHovering = true }
        }
        hideControls(after: .seconds(3))
    }

    private func hideControls(after delay: Duration) {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { isHovering = false }
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

        case .loaded(.synced):
            LyricsListView(
                lines: lyrics.timedLines,
                playbackState: state,
                animate: environment.renderGate.canAnimate && environment.windows.canRenderLyrics,
                offset: environment.offsets.offset(for: state.track),
                palette: nowPlaying.palette,
                fontSize: settings.fontSize,
                alignment: settings.lyricAlignment,
                visibleLinesMode: settings.visibleLinesMode,
                effect: settings.lyricEffect,
                onSeek: { environment.seek(toLyricTime: $0) }
            )
            .background { OffsetShortcuts(environment: environment) }

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
        case .loaded(.synced):
            CompactLyricLine(
                environment: environment,
                lines: lyrics.timedLines,
                state: state,
                fallback: fallback,
                fontSize: min(settings.fontSize, 20)
            )
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

/// The current line in the compact bar, always drawn with Karaoke Fill (it fits one row).
private struct CompactLyricLine: View {
    let environment: AppEnvironment
    let lines: [TimedLine]
    let state: PlaybackState
    let fallback: String
    let fontSize: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !(state.isPlaying && environment.renderGate.canAnimate && environment.windows.canRenderLyrics))) { timeline in
            let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
            Group {
                if let index {
                    LiveLyricEffect(
                        kind: .karaokeFill,
                        line: lines[index],
                        palette: environment.nowPlaying.palette,
                        fontSize: fontSize,
                        alignment: .leading,
                        isPlaying: state.isPlaying && environment.renderGate.canAnimate && environment.windows.canRenderLyrics,
                        lyricTime: { environment.lyricTime(state, at: $0) }
                    )
                    .lineLimit(1)
                } else {
                    Text(fallback).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .id(index ?? -1)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: index)
        }
    }
}

/// Glass bar with transport and scrubber, revealed while the pointer is over the window.
private struct ControlBar: View {
    let nowPlaying: NowPlayingStore
    let state: PlaybackState
    let animate: Bool
    var material: SurfaceMaterial = .frosted
    var hint: (HotkeyAction) -> String? = { _ in nil }

    var body: some View {
        VStack(spacing: 6) {
            TransportControls(nowPlaying: nowPlaying, isPlaying: state.isPlaying, hint: hint)
            Scrubber(state: state, tint: nowPlaying.palette.highlight, animate: animate) { nowPlaying.seek(to: $0) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SurfaceBackground(material: material, shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                                      darkening: 0, interactive: true, solidColor: Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}

/// Space plays/pauses; ← / → seek 5 s back/forward (when the lyrics window is focused).
private struct PlaybackShortcuts: View {
    let nowPlaying: NowPlayingStore
    var onClose: () -> Void = {}

    var body: some View {
        ZStack {
            Button("") { nowPlaying.playPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { skip(-5) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { skip(5) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("", action: onClose)
                .keyboardShortcut("w")
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func skip(_ seconds: TimeInterval) {
        guard let state = nowPlaying.playbackState else { return }
        nowPlaying.seek(to: state.interpolatedPosition() + seconds)
    }
}

/// Window-local shortcuts: ⌘] lyrics earlier, ⌘[ later, ⌘0 reset offset.
private struct OffsetShortcuts: View {
    let environment: AppEnvironment

    var body: some View {
        ZStack {
            Button("") { environment.nudgeOffset(by: OffsetStore.step) }
                .keyboardShortcut("]", modifiers: .command)
            Button("") { environment.nudgeOffset(by: -OffsetStore.step) }
                .keyboardShortcut("[", modifiers: .command)
            Button("") { environment.offsets.reset(environment.nowPlaying.currentTrack) }
                .keyboardShortcut("0", modifiers: .command)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

/// Translucent material washed with the album's colors. While music plays, three soft pools
/// of light drift slowly (15 fps, radial gradients only: no blur filters); paused, they rest.
struct AlbumBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: AlbumPalette
    let tinted: Bool
    var animated: Bool = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if tinted {
                LinearGradient(
                    colors: [palette.primary, palette.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.22)
                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !animated || reduceMotion)) { timeline in
                    DriftingLight(palette: palette, time: timeline.date.timeIntervalSinceReferenceDate)
                }
                .opacity(0.55)
                .blendMode(.plusLighter)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: palette)
        .ignoresSafeArea()
    }
}

private struct DriftingLight: View {
    let palette: AlbumPalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            let blobs: [(color: Color, speed: Double, phase: Double, radius: CGFloat)] = [
                (palette.primary, 0.050, 0.0, 0.75),
                (palette.accent, 0.037, 2.1, 0.6),
                (palette.highlight, 0.043, 4.2, 0.5)
            ]
            let span = max(size.width, size.height)
            for blob in blobs {
                let t = time * blob.speed + blob.phase
                let center = CGPoint(
                    x: size.width * (0.5 + 0.38 * sin(t * 1.3)),
                    y: size.height * (0.5 + 0.34 * cos(t))
                )
                let radius = span * blob.radius
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [blob.color.opacity(0.55), blob.color.opacity(0)]),
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}
