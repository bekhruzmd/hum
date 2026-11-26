import SwiftUI

/// Synced lyrics with the active line drawn by the chosen effect.
///
/// A coarse 10 Hz timeline only works out which line is active; the list below is `Equatable`,
/// so it re-renders only when that changes. The active line has its own 60 fps timeline.
struct LyricsListView: View {
    let lines: [TimedLine]
    let playbackState: PlaybackState
    let offset: TimeInterval
    let palette: AlbumPalette
    let fontSize: Double
    let alignment: LyricAlignment
    let visibleLinesMode: VisibleLinesMode
    let effect: LyricEffectKind
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !playbackState.isPlaying)) { timeline in
            let time = playbackState.interpolatedPosition(at: timeline.date) + offset
            LyricLinesBody(
                lines: lines,
                activeIndex: lines.activeIndex(at: time),
                playbackState: playbackState,
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
    let lines: [TimedLine]
    let activeIndex: Int?
    let playbackState: PlaybackState
    let offset: TimeInterval
    let palette: AlbumPalette
    let fontSize: Double
    let alignment: LyricAlignment
    let visibleLinesMode: VisibleLinesMode
    let effect: LyricEffectKind
    let onSeek: (TimeInterval) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.activeIndex == rhs.activeIndex
            && lhs.lines == rhs.lines
            && lhs.playbackState == rhs.playbackState
            && lhs.offset == rhs.offset
            && lhs.palette == rhs.palette
            && lhs.fontSize == rhs.fontSize
            && lhs.alignment == rhs.alignment
            && lhs.visibleLinesMode == rhs.visibleLinesMode
            && lhs.effect == rhs.effect
    }

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
                LazyVStack(alignment: alignment.horizontalAlignment, spacing: 14) {
                    ForEach(lines) { line in
                        row(line).id(line.id)
                    }
                }
                .padding(.vertical, 40)
            }
            .scrollIndicators(.hidden)
            .onChange(of: activeIndex) { _, newIndex in
                guard let newIndex, lines.indices.contains(newIndex) else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
            .onAppear {
                if let activeIndex, lines.indices.contains(activeIndex) {
                    proxy.scrollTo(lines[activeIndex].id, anchor: .center)
                }
            }
        }
    }

    private func windowed(radius: Int) -> some View {
        let center = activeIndex ?? 0
        let visible = lines.isEmpty ? [] : Array(lines[max(0, center - radius)...min(lines.count - 1, center + radius)])
        return VStack(alignment: alignment.horizontalAlignment, spacing: 16) {
            Spacer(minLength: 0)
            ForEach(visible) { line in
                row(line).transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeIndex)
    }

    @ViewBuilder
    private func row(_ line: TimedLine) -> some View {
        let isActive = activeIndex.map { lines[$0].id == line.id } ?? false
        Button {
            onSeek(line.start)
        } label: {
            if isActive {
                LiveLyricEffect(
                    kind: effect,
                    line: line,
                    palette: palette,
                    fontSize: fontSize,
                    alignment: alignment,
                    isPlaying: playbackState.isPlaying,
                    lyricTime: { playbackState.interpolatedPosition(at: $0) + offset }
                )
                .transition(.opacity)
            } else {
                InactiveLine(text: line.displayText, fontSize: fontSize, alignment: alignment)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Plays from this line")
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }
}

private struct InactiveLine: View {
    let text: String
    let fontSize: Double
    let alignment: LyricAlignment

    @State private var isHovered = false

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .multilineTextAlignment(alignment.textAlignment)
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 0.8 : 0.5)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}
