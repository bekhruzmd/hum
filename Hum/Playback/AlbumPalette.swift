import SwiftUI

/// An sRGB color with components in 0...1.
struct RGB: Sendable, Equatable, Codable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    /// Relative luminance (Rec. 709), 0...1.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
}

/// The three dominant colors of an album cover, most common first.
struct AlbumPalette: Sendable, Equatable, Codable {
    var colors: [RGB]

    static let fallback = AlbumPalette(colors: [
        RGB(r: 0.30, g: 0.32, b: 0.42),
        RGB(r: 0.18, g: 0.20, b: 0.28),
        RGB(r: 0.55, g: 0.50, b: 0.62)
    ])

    var primary: Color { color(at: 0) }
    var secondary: Color { color(at: 1) }
    var accent: Color { color(at: 2) }

    func color(at index: Int) -> Color {
        guard !colors.isEmpty else { return Self.fallback.color(at: index) }
        return colors[index % colors.count].color
    }

    /// The most saturated, mid-bright color: good for highlights over a dark background.
    var highlight: Color {
        let scored = colors.max { score($0) < score($1) }
        return (scored ?? Self.fallback.colors[2]).color
    }

    private func score(_ c: RGB) -> Double {
        let maxC = max(c.r, c.g, c.b), minC = min(c.r, c.g, c.b)
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
        return saturation + (1 - abs(c.luminance - 0.55))
    }
}
