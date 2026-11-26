import AppKit
import XCTest
@testable import Hum

final class ColorExtractorTests: XCTestCase {
    func testDominantColorsOrderedBySize() {
        let red = SIMD3<Double>(1, 0, 0), blue = SIMD3<Double>(0, 0, 1), green = SIMD3<Double>(0, 1, 0)
        let pixels = Array(repeating: red, count: 60) + Array(repeating: blue, count: 30) + Array(repeating: green, count: 10)
        let colors = ColorExtractor.dominantColors(in: pixels, k: 3)
        XCTAssertEqual(colors.count, 3)
        guard colors.count == 3 else { return }
        XCTAssertEqual(colors[0], RGB(r: 1, g: 0, b: 0))
        XCTAssertEqual(colors[1], RGB(r: 0, g: 0, b: 1))
        XCTAssertEqual(colors[2], RGB(r: 0, g: 1, b: 0))
    }

    func testDeterministic() {
        let pixels = (0..<500).map { i in SIMD3<Double>(Double(i % 7) / 7, Double(i % 11) / 11, Double(i % 13) / 13) }
        XCTAssertEqual(ColorExtractor.dominantColors(in: pixels, k: 3), ColorExtractor.dominantColors(in: pixels, k: 3))
    }

    func testPaletteFromPNGData() throws {
        let size = 64
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<size {
            for y in 0..<size {
                rep.setColor(x < 48 ? NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 1) : NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1), atX: x, y: y)
            }
        }
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let palette = try XCTUnwrap(ColorExtractor.palette(from: png))
        XCTAssertFalse(palette.colors.isEmpty)
        // The largest cluster should be the orange 3/4 of the image.
        XCTAssertGreaterThan(palette.colors[0].r, 0.7)
    }

    func testEmptyInput() {
        XCTAssertTrue(ColorExtractor.dominantColors(in: [], k: 3).isEmpty)
        XCTAssertNil(ColorExtractor.palette(from: Data([1, 2, 3])))
    }

    func testDominantGlowColorSelection() {
        // 1. Cover with dark neutral background and a vibrant accent:
        // Dominant cluster is near-black, accent is cyan/magenta.
        let darkBg = RGB(r: 0.04, g: 0.04, b: 0.05)
        let midGrey = RGB(r: 0.12, g: 0.12, b: 0.14)
        let vibrantPink = RGB(r: 0.95, g: 0.15, b: 0.65)
        let paletteWithDarkBg = AlbumPalette(colors: [darkBg, midGrey, vibrantPink])
        XCTAssertEqual(paletteWithDarkBg.dominantGlowColor, vibrantPink, "Should select standout accent when dominant is dark neutral")

        // 2. Cover with bright rich dominant color (e.g. orange album cover):
        let richOrange = RGB(r: 0.90, g: 0.45, b: 0.10)
        let softYellow = RGB(r: 0.85, g: 0.70, b: 0.20)
        let darkBrown = RGB(r: 0.25, g: 0.15, b: 0.08)
        let paletteWithVibrantDominant = AlbumPalette(colors: [richOrange, softYellow, darkBrown])
        XCTAssertEqual(paletteWithVibrantDominant.dominantGlowColor, richOrange, "Should select dominant color when it is vibrant")
    }
}
