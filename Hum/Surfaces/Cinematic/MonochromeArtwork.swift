import AppKit
import CoreImage

/// Pre-renders a contrasty black-and-white copy of the cover once per image, so the
/// cinematic scene doesn't run a color filter over a full-screen image every frame.
@MainActor
enum MonochromeArtwork {
    private static var cache: (key: ObjectIdentifier, image: NSImage)?
    private static let context = CIContext()

    static func image(for artwork: NSImage?) -> NSImage? {
        guard let artwork else { return nil }
        let key = ObjectIdentifier(artwork)
        if let cache, cache.key == key { return cache.image }
        guard let cg = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let output = CIImage(cgImage: cg)
            .applyingFilter("CIPhotoEffectNoir")
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.12, kCIInputBrightnessKey: -0.04])
        guard let rendered = context.createCGImage(output, from: output.extent) else { return nil }
        let image = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
        cache = (key, image)
        return image
    }
}
