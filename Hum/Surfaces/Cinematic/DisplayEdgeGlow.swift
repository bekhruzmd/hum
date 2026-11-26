import SwiftUI

struct DisplayEdgeGlow: View {
    let contour: DisplayEdgeContour
    let time: TimeInterval
    let intensity: Double
    var color: RGB = RGB(r: 0.65, g: 0.82, b: 1.0)

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
                    .float4(Float(color.r), Float(color.g), Float(color.b), 1.0)
                ))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private final class EdgeGlowShaderBundle: NSObject {}
