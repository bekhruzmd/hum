import SwiftUI

/// Everything an effect needs to draw the active line at one instant.
struct LyricRenderContext {
    let line: TimedLine
    /// Lyric time in seconds (playback position + offset).
    let time: TimeInterval
    let palette: AlbumPalette
    let fontSize: CGFloat
    let alignment: LyricAlignment

    var progress: Double { line.progress(at: time) }
    var currentWordIndex: Int? { line.currentWordIndex(at: time) }
    func fill(ofWord index: Int) -> Double { line.fill(ofWord: index, at: time) }
}

/// A way of drawing the active lyric line. Effects are pure functions of the context, so the
/// same effect renders the lyrics window, the island, the desktop and the idle screen.
@MainActor
protocol LyricEffect {
    associatedtype Body: View
    @ViewBuilder func render(_ context: LyricRenderContext) -> Body
}

enum LyricEffectKind: String, CaseIterable, Identifiable, Sendable {
    case karaokeFill
    case bigWords
    case glow
    case typewriter
    case wave

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .karaokeFill: return "Karaoke Fill"
        case .bigWords: return "Big Words"
        case .glow: return "Glow"
        case .typewriter: return "Typewriter"
        case .wave: return "Wave"
        }
    }
}

/// Draws `context` with the chosen effect, or a plain fade when Reduce Motion is on.
struct LyricEffectView: View {
    let kind: LyricEffectKind
    let context: LyricRenderContext

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                FadeEffect().render(context)
            } else {
                switch kind {
                case .karaokeFill: KaraokeFillEffect().render(context)
                case .bigWords: BigWordsEffect().render(context)
                case .glow: GlowEffect().render(context)
                case .typewriter: TypewriterEffect().render(context)
                case .wave: WaveEffect().render(context)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.line.displayText)
    }
}

/// Wraps the effect in an animation-driven timeline that stops while paused or hidden.
struct LiveLyricEffect: View {
    let kind: LyricEffectKind
    let line: TimedLine
    let palette: AlbumPalette
    let fontSize: CGFloat
    let alignment: LyricAlignment
    let isPlaying: Bool
    let lyricTime: (Date) -> TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
            LyricEffectView(
                kind: kind,
                context: LyricRenderContext(
                    line: line,
                    time: lyricTime(timeline.date),
                    palette: palette,
                    fontSize: fontSize,
                    alignment: alignment
                )
            )
        }
    }
}
