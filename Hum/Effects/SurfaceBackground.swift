import SwiftUI

/// The background of a floating surface in the chosen `SurfaceMaterial`.
///
/// - Liquid Glass: Apple's system glass (macOS 26+), lightly darkened so white text stays legible.
/// - Frosted: a blur of what's behind, darkened.
/// - Solid: an opaque near-black, also used when Reduce Transparency is on.
struct SurfaceBackground<S: Shape>: View {
    let material: SurfaceMaterial
    let shape: S
    /// How much black to lay over glass or frost, for legibility (0…1).
    var darkening: Double = 0.38
    /// Liquid Glass reacts to the pointer (subtle highlight on hover and press).
    var interactive = false
    /// Opaque fill for Solid. Surfaces that follow light/dark mode pass a system color.
    var solidColor: Color = Color(white: 0.07)

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        switch material.resolved(reduceTransparency: reduceTransparency) {
        case .liquidGlass:
            if #available(macOS 26, *) {
                let glass = darkening > 0 ? Glass.regular.tint(.black.opacity(darkening)) : Glass.regular
                Color.clear
                    .glassEffect(interactive ? glass.interactive() : glass, in: shape)
            } else {
                frosted
            }
        case .frosted:
            frosted
        case .solid:
            shape.fill(solidColor)
        }
    }

    private var frosted: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            if darkening > 0 { shape.fill(.black.opacity(darkening)) }
        }
    }
}
