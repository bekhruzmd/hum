import SwiftUI

struct DisplayEdgeGlow: View {
    let contour: DisplayEdgeContour
    let time: TimeInterval
    let intensity: Double
    var color: RGB = RGB(r: 0.65, g: 0.82, b: 1.0)
    var appearance: GlowAppearance = .default
    /// 0…1 beat energy (see `BeatPulse`).
    var pulse: Double = 0

    var body: some View {
        if intensity > 0 {
            Rectangle().fill(.white)
                .colorEffect(ShaderLibrary.bundle(Bundle(for: EdgeGlowShaderBundle.self)).humEdgeGlow(
                    .float2(Float(contour.size.width), Float(contour.size.height)),
                    .float4(Float(contour.camera.minX), Float(contour.camera.minY), Float(contour.camera.width), Float(contour.camera.height)),
                    .float4(Float(contour.topRadius), Float(contour.bottomRadius), Float(contour.cameraRadius), contour.isPill ? 1 : 0),
                    .float(Float(contour.scale)),
                    .float(Float(time)),
                    .float(Float(CinematicGlow.clamped(intensity))),
                    .float4(Float(color.r), Float(color.g), Float(color.b), 1.0),
                    .float4(appearance.style.shaderIndex, Float(appearance.speed), Float(appearance.thickness),
                            appearance.colorMode == .spectrum ? 1 : 0),
                    .float(Float(min(1, max(0, pulse))))
                ))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private final class EdgeGlowShaderBundle: NSObject {}

/// Beat energy for the glow, derived from lyric word timings: each sung word flares and decays.
/// Songs without synced lyrics get a gentle steady breath while playing.
enum BeatPulse {
    static let decay: TimeInterval = 0.22

    static func value(lines: [TimedLine], time: TimeInterval, isPlaying: Bool, followsLyrics: Bool = true) -> Double {
        guard isPlaying else { return 0 }
        guard followsLyrics, !lines.isEmpty, let index = lines.activeIndex(at: time) else {
            return breath(at: time)
        }
        var energy = 0.0
        for lineIndex in max(0, index - 1)...index {
            for word in lines[lineIndex].words where word.start <= time {
                let age = time - word.start
                if age < decay * 5 { energy += exp(-age / decay) }
            }
        }
        // Long instrumental gaps fall back to the breath so the rim never goes dead.
        return energy > 0.02 ? min(1, energy) : breath(at: time) * 0.6
    }

    static func breath(at time: TimeInterval) -> Double {
        0.25 + 0.25 * sin(time * 2 * .pi * 0.45)
    }
}
