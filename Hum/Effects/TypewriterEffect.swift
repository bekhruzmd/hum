import SwiftUI

/// Characters appear one by one in a monospaced face, following the word timings, with a caret.
struct TypewriterEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let text = context.line.displayText
        let revealed = revealedCount(context, total: text.count)
        let shown = String(text.prefix(revealed))
        let hidden = String(text.dropFirst(revealed))
        let caretOn = Int(context.time * 2.5) % 2 == 0 || revealed < text.count
        let font = Font.system(size: context.fontSize, weight: .medium, design: .monospaced)

        // The hidden tail keeps its space so wrapping doesn't jump as letters appear.
        (Text(shown).foregroundStyle(.primary)
            + Text(caretOn ? "▍" : " ").foregroundStyle(context.palette.highlight)
            + Text(hidden).foregroundStyle(.clear))
            .font(font)
            .multilineTextAlignment(context.alignment.textAlignment)
            .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }

    /// Maps word progress onto characters of the full line (including spaces).
    private func revealedCount(_ context: LyricRenderContext, total: Int) -> Int {
        let words = context.line.words
        guard !words.isEmpty else { return Int((context.progress * Double(total)).rounded(.down)) }
        var count = 0
        for (index, word) in words.enumerated() {
            let fill = context.fill(ofWord: index)
            if fill >= 1 {
                count += word.text.count + 1
            } else {
                count += Int((fill * Double(word.text.count)).rounded(.down))
                break
            }
        }
        return min(total, count)
    }
}
