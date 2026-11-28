import AppKit
import UniformTypeIdentifiers

/// Dragging cover art out of Hum: a PNG file named after the song, so it lands as a real file
/// in the Finder and as an image in apps like Messages or Preview.
@MainActor
enum ArtworkDrag {
    static func provider(for image: NSImage?, title: String) -> NSItemProvider {
        guard let image else { return NSItemProvider() }
        if let url = writePNG(image, title: title), let provider = NSItemProvider(contentsOf: url) {
            return provider
        }
        return NSItemProvider(object: image)
    }

    private static func writePNG(_ image: NSImage, title: String) -> URL? {
        guard
            let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return nil }
        let safeName = title.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HumArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(safeName.isEmpty ? "Artwork" : safeName).appendingPathExtension("png")
        do {
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
