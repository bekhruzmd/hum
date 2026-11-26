import SwiftUI

/// Each word fills from left to right as it is sung, over a dimmed copy.
struct KaraokeFillEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.layoutWords
        FlowLayout(alignment: context.alignment, spacing: context.wordSpacing, lineSpacing: context.rowSpacing) {
            ForEach(words.indices, id: \.self) { index in
                FillWord(
                    text: words[index].text,
                    fill: context.fillForLayoutWord(index),
                    fontSize: context.fontSize,
                    tint: context.palette.highlight
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}

private struct FillWord: View {
    let text: String
    let fill: Double
    let fontSize: CGFloat
    let tint: Color

    var body: some View {
        let label = Text(text).font(.system(size: fontSize, weight: .bold, design: .rounded))
        label
            .foregroundStyle(.primary.opacity(0.32))
            .overlay(alignment: .leading) {
                label
                    .foregroundStyle(.primary)
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: fill, y: 1, anchor: .leading)
                    }
                    .shadow(color: tint.opacity(fill > 0 && fill < 1 ? 0.8 : 0), radius: fontSize * 0.25)
            }
            .fixedSize()
    }
}
