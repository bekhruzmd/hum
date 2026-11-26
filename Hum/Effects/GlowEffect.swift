import SwiftUI

/// Sung words light up in the album's highlight color; the current word blooms brightest.
struct GlowEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.layoutWords
        let current = context.currentWordIndex ?? -1
        FlowLayout(alignment: context.alignment, spacing: context.wordSpacing, lineSpacing: context.rowSpacing) {
            ForEach(words.indices, id: \.self) { index in
                let fill = context.fillForLayoutWord(index)
                let isCurrent = index == current && fill < 1
                Text(words[index].text)
                    .font(.system(size: context.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(fill > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary.opacity(0.35)))
                    .shadow(
                        color: context.palette.highlight.opacity(fill > 0 ? (isCurrent ? 0.95 : 0.45) : 0),
                        radius: isCurrent ? context.fontSize * 0.45 : context.fontSize * 0.18
                    )
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}
