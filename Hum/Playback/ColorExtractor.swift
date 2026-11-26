import CoreGraphics
import Foundation
import ImageIO
import simd

/// Finds the dominant colors of an image: downscale to 32px, then k-means in RGB space.
enum ColorExtractor {
    static let sampleSize = 32

    static func palette(from imageData: Data, count: Int = 3) -> AlbumPalette? {
        guard let pixels = samplePixels(from: imageData), !pixels.isEmpty else { return nil }
        let colors = dominantColors(in: pixels, k: count)
        return colors.isEmpty ? nil : AlbumPalette(colors: colors)
    }

    /// Deterministic k-means. Seeds use farthest-point traversal starting from the median-
    /// luminance pixel, so results are stable for the same input and distinct colors each get
    /// a seed. Returns clusters sorted by size, largest first.
    static func dominantColors(in pixels: [SIMD3<Double>], k: Int, iterations: Int = 12) -> [RGB] {
        guard !pixels.isEmpty, k > 0 else { return [] }
        var centers = seeds(for: pixels, k: k)
        let k = centers.count
        var assignments = [Int](repeating: 0, count: pixels.count)

        for _ in 0..<iterations {
            for (index, pixel) in pixels.enumerated() {
                assignments[index] = nearest(pixel, in: centers)
            }
            var sums = [SIMD3<Double>](repeating: .zero, count: k)
            var counts = [Int](repeating: 0, count: k)
            for (index, pixel) in pixels.enumerated() {
                sums[assignments[index]] += pixel
                counts[assignments[index]] += 1
            }
            var moved = false
            for c in 0..<k where counts[c] > 0 {
                let updated = sums[c] / Double(counts[c])
                if simd_distance_squared(updated, centers[c]) > 1e-6 { moved = true }
                centers[c] = updated
            }
            if !moved { break }
        }

        var counts = [Int](repeating: 0, count: k)
        for a in assignments { counts[a] += 1 }
        return (0..<k)
            .filter { counts[$0] > 0 }
            .sorted { counts[$0] > counts[$1] }
            .map { RGB(r: centers[$0].x, g: centers[$0].y, b: centers[$0].z) }
    }

    private static func seeds(for pixels: [SIMD3<Double>], k: Int) -> [SIMD3<Double>] {
        let sorted = pixels.sorted { luminance($0) < luminance($1) }
        var centers = [sorted[sorted.count / 2]]
        var minDistances = pixels.map { simd_distance_squared($0, centers[0]) }
        while centers.count < k {
            guard let (index, distance) = minDistances.enumerated().max(by: { $0.element < $1.element }),
                  distance > 1e-6 else { break }
            let next = pixels[index]
            centers.append(next)
            for i in pixels.indices {
                minDistances[i] = min(minDistances[i], simd_distance_squared(pixels[i], next))
            }
        }
        return centers
    }

    private static func samplePixels(from data: Data) -> [SIMD3<Double>]? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: sampleSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // The thumbnail path is cheapest for large covers; fall back to a full decode.
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let width = min(image.width, sampleSize), height = min(image.height, sampleSize)
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var pixels: [SIMD3<Double>] = []
        pixels.reserveCapacity(width * height)
        for i in stride(from: 0, to: buffer.count, by: 4) where buffer[i + 3] > 128 {
            pixels.append(SIMD3(Double(buffer[i]), Double(buffer[i + 1]), Double(buffer[i + 2])) / 255.0)
        }
        return pixels
    }

    private static func nearest(_ pixel: SIMD3<Double>, in centers: [SIMD3<Double>]) -> Int {
        var best = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, center) in centers.enumerated() {
            let distance = simd_distance_squared(pixel, center)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    private static func luminance(_ p: SIMD3<Double>) -> Double {
        0.2126 * p.x + 0.7152 * p.y + 0.0722 * p.z
    }
}
