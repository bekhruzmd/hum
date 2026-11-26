import SwiftUI

/// Sung words light up in the album's highlight color; the current word blooms brightest.
struct GlowEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.layoutWords
        let current = context.currentWordIndex ?? -1
        FlowLayout(alignment: context.alignment, spacing: context.wordSpacing, lineSpacing: context.rowSpacing) {
            ForEach(words.indices, id: \.self) { index in
                let fill = context.fillForLayoutWord(index)
                let bloom = index == current ? sin(fill * .pi) : 0
                let reveal = min(1, fill * 6)
                Text(words[index].text)
                    .font(.system(size: context.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(AnyShapeStyle(.primary.opacity(0.35 + 0.65 * reveal)))
                    .shadow(
                        color: context.palette.highlight.opacity(reveal * (0.3 + bloom * 0.5)),
                        radius: context.fontSize * (0.14 + bloom * 0.2)
                    )
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}
