import SwiftUI

/// One word at a time, very large, popping in as it's sung. The next word waits faintly below.
struct BigWordsEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.layoutWords
        let index = min(words.count - 1, max(0, context.currentWordIndex ?? 0))
        let fill = context.fillForLayoutWord(index)
        let pop = 1 + 0.08 * (1 - min(1, fill * 3))
        let next = index + 1 < words.count ? words[index + 1].text : " "

        VStack(alignment: context.alignment.horizontalAlignment, spacing: context.fontSize * 0.2) {
            Text(words[index].text)
                .font(.system(size: context.fontSize * 2.2, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, context.palette.highlight],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .scaleEffect(pop, anchor: context.alignment.unitPoint)
                .id(index)
                .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .opacity))
            Text(next)
                .font(.system(size: context.fontSize * 0.9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: index)
    }
}
