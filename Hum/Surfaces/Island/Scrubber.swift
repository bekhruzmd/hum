import SwiftUI

/// A thin progress bar you can drag or click to seek. Seeks once, on release.
struct Scrubber: View {
    let state: PlaybackState
    let tint: Color
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !state.isPlaying || dragFraction != nil)) { timeline in
            let duration = max(1, state.track.duration)
            let position = state.interpolatedPosition(at: timeline.date)
            let fraction = dragFraction ?? min(1, position / duration)
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule().fill(tint).frame(width: max(4, proxy.size.width * fraction))
                    }
                    .frame(height: dragFraction == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = min(1, max(0, value.location.x / proxy.size.width))
                            }
                            .onEnded { _ in
                                if let dragFraction { onSeek(dragFraction * duration) }
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 12)
                HStack {
                    Text(Self.format(fraction * duration))
                    Spacer()
                    Text("-" + Self.format(max(0, duration - fraction * duration)))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(Self.format(state.interpolatedPosition()))
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = direction == .increment ? 10 : -10
            onSeek(max(0, state.interpolatedPosition() + step))
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
