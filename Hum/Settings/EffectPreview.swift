import SwiftUI

/// Loops a demo line through the chosen effect so Settings can show it live.
struct EffectPreview: View {
    let kind: LyricEffectKind
    let palette: AlbumPalette
    let alignment: LyricAlignment

    private static let line: TimedLine = {
        let lyric = LyricLine(id: 0, time: 0, text: "Hold the note and let the city hum along")
        return WordTimingEstimator.timedLine(for: lyric, nextStart: 4.2)
    }()
    private static let loop: TimeInterval = 5.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop) - 0.4
            LyricEffectView(
                kind: kind,
                context: LyricRenderContext(
                    line: Self.line,
                    time: time,
                    palette: palette,
                    fontSize: 20,
                    alignment: alignment
                )
            )
        }
        .padding(16)
        // Fixed height: effects differ in size, and the preview must never resize its container.
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .clipped()
        .background {
            AlbumBackground(palette: palette, tinted: true)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel("Preview of the \(kind.displayName) effect")
    }
}
