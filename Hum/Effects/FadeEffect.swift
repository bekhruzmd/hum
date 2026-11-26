import SwiftUI

/// The Reduce Motion fallback: the whole line, fully bright, no per-word motion.
struct FadeEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        Text(context.line.displayText)
            .font(.system(size: context.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(context.alignment.textAlignment)
            .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}
