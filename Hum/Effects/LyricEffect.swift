import SwiftUI

/// Everything an effect needs to draw the active line at one instant.
struct LyricRenderContext {
    let line: TimedLine
    /// Lyric time in seconds (playback position + offset).
    let time: TimeInterval
    let palette: AlbumPalette
    let fontSize: CGFloat
    let alignment: LyricAlignment
    /// The line before, for effects that keep a trace of it (Constellation).
    var previous: TimedLine? = nil

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
    case constellation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .karaokeFill: return "Karaoke Fill"
        case .bigWords: return "Big Words"
        case .glow: return "Glow"
        case .typewriter: return "Typewriter"
        case .wave: return "Wave"
        case .constellation: return "Constellation"
        }
    }

    /// Continuous fills and movement use display cadence; discrete character reveals and
    /// slow light changes need only 30 frames per second.
    var framesPerSecond: Double {
        switch self {
        case .constellation, .typewriter, .glow: return 30
        default: return 60
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
                case .constellation: ConstellationEffect().render(context)
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
    var previous: TimedLine? = nil
    let lyricTime: (Date) -> TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // The owning surface advances line selection. Static text needs no frame timer.
            FadeEffect().render(context(at: Date()))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / kind.framesPerSecond, paused: !isPlaying)) { timeline in
                LyricEffectView(kind: kind, context: context(at: timeline.date))
            }
        }
    }

    private func context(at date: Date) -> LyricRenderContext {
        LyricRenderContext(
            line: line, time: lyricTime(date), palette: palette,
            fontSize: fontSize, alignment: alignment, previous: previous
        )
    }

    /// Effects too tall for one-row surfaces (island, compact bar) fall back to Karaoke Fill.
    static func singleRow(_ kind: LyricEffectKind) -> LyricEffectKind {
        switch kind {
        case .bigWords, .constellation: return .karaokeFill
        default: return kind
        }
    }
}
