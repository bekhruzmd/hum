import SwiftUI

struct LyricsListView: View {
    let lines: [LyricLine]
    let playbackState: PlaybackState

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !playbackState.isPlaying)) { context in
            let currentPosition = playbackState.interpolatedPosition(at: context.date)
            let activeIndex = LRCParser.activeLineIndex(in: lines, at: currentPosition)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                            let isActive = (index == activeIndex)
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(isActive ? .title3.weight(.semibold) : .body)
                                .foregroundStyle(isActive ? .primary : .secondary)
                                .opacity(isActive ? 1.0 : 0.45)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                                .animation(.easeInOut(duration: 0.2), value: activeIndex)
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
    }
}
