import SwiftUI

/// Four small level bars that dance while playing and rest flat when paused.
/// The timeline is paused (no redraws) whenever playback is.
struct PlaybackBars: View {
    let isPlaying: Bool
    let color: Color
    var barWidth: CGFloat = 3
    var height: CGFloat = 14

    private static let phases: [Double] = [0, 1.7, 0.9, 2.6]
    private static let speeds: [Double] = [7.1, 5.3, 8.4, 6.2]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: barWidth * 0.8) {
                ForEach(0..<4, id: \.self) { i in
                    let level = isPlaying
                        ? 0.35 + 0.65 * abs(sin(t * Self.speeds[i] / 2 + Self.phases[i]))
                        : 0.22
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: max(barWidth, height * level))
                }
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}
