import AppKit
import CoreImage

/// Pre-renders a heavily blurred, darkened copy of the cover once per album, so full-screen
/// backgrounds don't pay for a live blur every frame.
@MainActor
enum BlurredArtwork {
    private static var cache: (key: ObjectIdentifier, image: NSImage)?
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(for artwork: NSImage?) -> NSImage? {
        guard let artwork else { return nil }
        let key = ObjectIdentifier(artwork)
        if let cache, cache.key == key { return cache.image }

        guard
            let cg = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let input = CIImage(cgImage: cg)
        let scale = 256 / max(input.extent.width, input.extent.height)
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blurred = small
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 18)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.3,
                kCIInputBrightnessKey: -0.18
            ])
            .cropped(to: small.extent)
        guard let output = context.createCGImage(blurred, from: small.extent) else { return nil }
        let image = NSImage(cgImage: output, size: NSSize(width: output.width, height: output.height))
        cache = (key, image)
        return image
    }
}
