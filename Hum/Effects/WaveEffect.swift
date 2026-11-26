import SwiftUI

/// Words ride a gentle sine wave; the word being sung lifts and brightens.
struct WaveEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.layoutWords
        let current = context.currentWordIndex ?? -1
        let amplitude = context.fontSize * 0.12
        FlowLayout(alignment: context.alignment, spacing: context.wordSpacing, lineSpacing: context.rowSpacing) {
            ForEach(words.indices, id: \.self) { index in
                let fill = context.fillForLayoutWord(index)
                let lift = index == current ? sin(fill * .pi) * context.fontSize * 0.3 : 0
                let wave = sin(context.time * 3 + Double(index) * 0.8) * amplitude
                Text(words[index].text)
                    .font(.system(size: context.fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(AnyShapeStyle(.primary.opacity(0.35 + 0.65 * min(1, fill * 6))))
                    .scaleEffect(index == current ? 1 + 0.1 * sin(fill * .pi) : 1)
                    .offset(y: wave - lift)
                    .fixedSize()
            }
        }
        .padding(.vertical, context.fontSize * 0.35)
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}
