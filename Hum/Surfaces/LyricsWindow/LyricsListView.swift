import SwiftUI

/// A stretch with no singing: the intro before the first line, a long break after a line,
/// or an empty LRC line ("♪").
struct LyricGap: Equatable {
    let start: TimeInterval
    let end: TimeInterval

    /// Gaps shorter than this aren't worth showing.
    static let minimumLength: TimeInterval = 3.5

    static func find(in lines: [TimedLine], activeIndex: Int?, time: TimeInterval) -> LyricGap? {
        guard let first = lines.first else { return nil }
        guard let index = activeIndex else {
            return first.start >= minimumLength ? LyricGap(start: 0, end: first.start) : nil
        }
        guard index + 1 < lines.count else { return nil }
        let line = lines[index]
        let nextStart = lines[index + 1].start
        if line.text.isEmpty, nextStart - line.start >= minimumLength {
            return LyricGap(start: line.start, end: nextStart)
        }
        // Wait a beat after the line ends before declaring a break.
        let breakStart = line.end + 0.6
        guard time >= breakStart, nextStart - breakStart >= minimumLength else { return nil }
        return LyricGap(start: breakStart, end: nextStart)
    }

    func progress(at time: TimeInterval) -> Double {
        min(1, max(0, (time - start) / max(0.001, end - start)))
    }
}

/// Synced lyrics with the active line drawn by the chosen effect.
///
/// A coarse 10 Hz timeline only works out which line is active (and whether we're in a
/// break); the list below is `Equatable`, so it re-renders only when that changes. The active
/// line has its own 60 fps timeline.
struct LyricsListView: View {
    let lines: [TimedLine]
    let playbackState: PlaybackState
    let animate: Bool
    let offset: TimeInterval
    let palette: AlbumPalette
    let fontSize: Double
    let alignment: LyricAlignment
    let visibleLinesMode: VisibleLinesMode
    let effect: LyricEffectKind
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !(animate && playbackState.isPlaying))) { timeline in
            let time = playbackState.interpolatedPosition(at: timeline.date) + offset
            let activeIndex = lines.activeIndex(at: time)
            LyricLinesBody(
                lines: lines,
                activeIndex: activeIndex,
                gap: LyricGap.find(in: lines, activeIndex: activeIndex, time: time),
                playbackState: playbackState,
                animate: animate,
                offset: offset,
                palette: palette,
                fontSize: fontSize,
                alignment: alignment,
                visibleLinesMode: visibleLinesMode,
                effect: effect,
                onSeek: onSeek
            )
            .equatable()
        }
    }
}

private struct LyricLinesBody: View, Equatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let lines: [TimedLine]
    let activeIndex: Int?
    let gap: LyricGap?
    let playbackState: PlaybackState
    let animate: Bool
    let offset: TimeInterval
    let palette: AlbumPalette
    let fontSize: Double
    let alignment: LyricAlignment
    let visibleLinesMode: VisibleLinesMode
    let effect: LyricEffectKind
    let onSeek: (TimeInterval) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.activeIndex == rhs.activeIndex
            && lhs.gap == rhs.gap
            && lhs.lines == rhs.lines
            && lhs.playbackState == rhs.playbackState
            && lhs.animate == rhs.animate
            && lhs.offset == rhs.offset
            && lhs.palette == rhs.palette
            && lhs.fontSize == rhs.fontSize
            && lhs.alignment == rhs.alignment
            && lhs.visibleLinesMode == rhs.visibleLinesMode
            && lhs.effect == rhs.effect
    }

    private var scrollSpring: Animation? { reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.95) }

    var body: some View {
        switch visibleLinesMode {
        case .all: allLines
        case .three: windowed(radius: 1)
        case .one: windowed(radius: 0)
        }
    }

    private var allLines: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: alignment.horizontalAlignment, spacing: fontSize * 0.8) {
                    if activeIndex == nil, let gap {
                        gapDots(gap).id("intro")
                    }
                    ForEach(lines.indices, id: \.self) { index in
                        row(index).id(lines[index].id)
                    }
                }
                .padding(.vertical, 60)
            }
            .scrollIndicators(.hidden)
            .mask(edgeFade)
            .onChange(of: activeIndex) { _, newIndex in
                guard let newIndex, lines.indices.contains(newIndex) else { return }
                withAnimation(scrollSpring) {
                    proxy.scrollTo(lines[newIndex].id, anchor: UnitPoint(x: 0.5, y: 0.4))
                }
            }
            .onAppear {
                if let activeIndex, lines.indices.contains(activeIndex) {
                    proxy.scrollTo(lines[activeIndex].id, anchor: UnitPoint(x: 0.5, y: 0.4))
                }
            }
        }
    }

    /// Soft fade at the top and bottom edges instead of a hard cut.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func windowed(radius: Int) -> some View {
        let center = activeIndex ?? 0
        let indices = lines.isEmpty ? [] : Array(max(0, center - radius)...min(lines.count - 1, center + radius))
        return VStack(alignment: alignment.horizontalAlignment, spacing: 16) {
            Spacer(minLength: 0)
            if activeIndex == nil, let gap {
                gapDots(gap)
            }
            ForEach(indices, id: \.self) { index in
                row(index).transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 18)),
                    removal: .opacity.combined(with: .offset(y: -18))
                ))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(scrollSpring, value: activeIndex)
    }

    @ViewBuilder
    private func row(_ index: Int) -> some View {
        let line = lines[index]
        let isActive = index == activeIndex
        let distance = activeIndex.map { index - $0 } ?? (index + 1)
        VStack(alignment: alignment.horizontalAlignment, spacing: fontSize * 0.5) {
            Button {
                onSeek(line.start)
            } label: {
                if isActive && !line.text.isEmpty && gap == nil {
                    LiveLyricEffect(
                        kind: effect,
                        line: line,
                        palette: palette,
                        fontSize: fontSize,
                        alignment: alignment,
                        isPlaying: animate && playbackState.isPlaying,
                        lyricTime: { playbackState.interpolatedPosition(at: $0) + offset }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: alignment.unitPoint)))
                } else if !(isActive && line.text.isEmpty) {
                    InactiveLine(text: line.displayText, fontSize: fontSize, alignment: alignment, distance: distance)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Plays from this line")
            .modifier(DraggableLyric(text: line.text))

            if isActive, let gap {
                gapDots(gap)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    private func gapDots(_ gap: LyricGap) -> some View {
        GapDots(
            gap: gap,
            tint: palette.highlight,
            size: fontSize * 0.5,
            alignment: alignment,
            isPlaying: animate && playbackState.isPlaying,
            lyricTime: { playbackState.interpolatedPosition(at: $0) + offset }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: alignment.unitPoint)))
    }
}

/// A non-active line. Lines fade and shrink with distance from the current line, which gives
/// the list depth; lines already sung sit a little dimmer than upcoming ones.
private struct InactiveLine: View {
    let text: String
    let fontSize: Double
    let alignment: LyricAlignment
    /// Signed distance from the active line (negative = already sung).
    let distance: Int

    @State private var isHovered = false

    var body: some View {
        let steps = Double(min(abs(distance), 6))
        let base = (distance < 0 ? 0.42 : 0.55) - steps * 0.06
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .multilineTextAlignment(alignment.textAlignment)
            .foregroundStyle(.primary)
            .opacity(isHovered ? 0.85 : max(0.14, base))
            .scaleEffect(1 - min(0.08, steps * 0.016), anchor: alignment.unitPoint)
            .blur(radius: isHovered ? 0 : max(0, steps - 2) * 0.35)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.18), value: isHovered)
    }
}

/// Three dots that fill one after another toward the next line, breathing gently, and
/// swell away just before singing resumes.
struct GapDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let gap: LyricGap
    let tint: Color
    let size: CGFloat
    let alignment: LyricAlignment
    let isPlaying: Bool
    let lyricTime: (Date) -> TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0, paused: !isPlaying)) { timeline in
            let time = lyricTime(timeline.date)
            let progress = gap.progress(at: time)
            let breathe = reduceMotion ? 1 : 1 + 0.06 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.4)
            // In the last 8% the dots swell and fade, handing over to the next line.
            let exit = max(0, (progress - 0.92) / 0.08)
            HStack(spacing: size * 0.7) {
                ForEach(0..<3, id: \.self) { i in
                    let fill = min(1, max(0, progress * 3 - Double(i)))
                    Circle()
                        .fill(.primary.opacity(0.22))
                        .overlay(Circle().fill(tint).opacity(fill))
                        .frame(width: size, height: size)
                        .scaleEffect(reduceMotion ? 1 : (0.8 + 0.2 * fill) * breathe * (1 + exit * 0.5))
                }
            }
            .opacity(1 - exit)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .padding(.vertical, size * 0.4)
        }
        .accessibilityLabel("Instrumental break")
    }
}

/// Lyric lines can be dragged out as text (into Notes, Messages, a document…).
private struct DraggableLyric: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        if text.isEmpty {
            content
        } else {
            content.draggable(text)
        }
    }
}
