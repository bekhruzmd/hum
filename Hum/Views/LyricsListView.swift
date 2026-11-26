import SwiftUI

struct LyricsListView: View {
    let lines: [LyricLine]
    let playbackState: PlaybackState
    let fontSize: Double
    let alignment: LyricAlignment
    let visibleLinesMode: VisibleLinesMode
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !playbackState.isPlaying)) { context in
            let currentPosition = playbackState.interpolatedPosition(at: context.date)
            let activeIndex = LRCParser.activeLineIndex(in: lines, at: currentPosition)

            switch visibleLinesMode {
            case .all:
                allLinesView(activeIndex: activeIndex)
            case .three:
                windowedLinesView(activeIndex: activeIndex, radius: 1)
            case .one:
                windowedLinesView(activeIndex: activeIndex, radius: 0)
            }
        }
    }

    private func allLinesView(activeIndex: Int?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: alignment.horizontalAlignment, spacing: 14) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        lyricRow(line: line, isActive: index == activeIndex)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 24)
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

    private func windowedLinesView(activeIndex: Int?, radius: Int) -> some View {
        let center = activeIndex ?? 0
        let lower = max(0, center - radius)
        let upper = min(lines.count - 1, center + radius)
        let visibleSlice = lines.isEmpty ? [] : Array(lines[lower...upper])

        return VStack(alignment: alignment.horizontalAlignment, spacing: 16) {
            Spacer(minLength: 0)
            ForEach(visibleSlice) { line in
                let isActive = (activeIndex != nil && line.id == lines[center].id)
                lyricRow(line: line, isActive: isActive)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeIndex)
    }

    private func lyricRow(line: LyricLine, isActive: Bool) -> some View {
        LyricRowButton(
            text: line.text.isEmpty ? "♪" : line.text,
            fontSize: fontSize,
            alignment: alignment,
            isActive: isActive,
            action: { onSeek(line.time) }
        )
    }
}

private struct LyricRowButton: View {
    let text: String
    let fontSize: Double
    let alignment: LyricAlignment
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: isActive ? .semibold : .regular))
                .multilineTextAlignment(alignment.textAlignment)
                .foregroundStyle(isActive ? .primary : .secondary)
                .opacity(isActive ? 1.0 : (isHovered ? 0.72 : 0.42))
                .scaleEffect(
                    isActive ? 1.03 : 0.96,
                    anchor: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center)
                )
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }
}
