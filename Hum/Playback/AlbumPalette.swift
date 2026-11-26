import SwiftUI

/// An sRGB color with components in 0...1.
struct RGB: Sendable, Equatable, Codable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    var saturation: Double {
        let maxC = max(r, g, b), minC = min(r, g, b)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

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

    /// Intelligent adaptive glow color algorithm based on the cover's color composition:
    /// - If the most dominant color is already vibrant and clear, use it (dominant).
    /// - If the cover is dominated by a dark/monochrome/neutral background (e.g. black, dark grey, white),
    ///   dominant background would look muddy or washed out, so select the most standing-out / vibrant accent color.
    /// - If the dominant color is a loud, overpowering wash, pick the subtle / least dominant accent to give depth.
    /// - Always ensures brightness and saturation are in the sweet spot for an emissive display edge light.
    var dominantGlowColor: RGB {
        guard !colors.isEmpty else { return Self.fallback.colors[0] }

        let primary = colors[0]
        let candidates = colors

        // 1. If cover background is heavily neutral / monochrome (e.g. black/grey/white background with a subject),
        // we definitely want the most standing-out accent color (highest pop score).
        if primary.saturation < 0.20 || primary.luminance < 0.10 || primary.luminance > 0.88 {
            let colored = candidates.filter { $0.saturation >= 0.20 && $0.luminance >= 0.12 && $0.luminance <= 0.85 }
            if let standout = colored.max(by: { standoutScore($0) < standoutScore($1) }) {
                return standout
            }
        }

        // 2. If the primary color is moderately or highly saturated:
        // Check if there is an exquisite standing out accent with strong contrast to the primary:
        let coloredAccents = candidates.dropFirst().filter { $0.saturation >= 0.25 && $0.luminance >= 0.15 && $0.luminance <= 0.82 }
        
        // If primary is loud (saturation > 0.65) and there's a softer, complementary least-dominant color,
        // or if an accent color stands out dramatically against the base:
        if let standout = coloredAccents.max(by: { standoutScore($0) < standoutScore($1) }) {
            // If the standout accent has significantly higher punch than primary, choose it
            if standoutScore(standout) > standoutScore(primary) * 1.35 {
                return standout
            }
        }

        // 3. Otherwise, use the dominant color, provided it is suitable for display illumination
        if primary.saturation >= 0.15 && primary.luminance >= 0.08 {
            return primary
        }

        // 4. Fallback to the candidate with the best overall balance for display lighting
        return candidates.max(by: { glowSuitability($0) < glowSuitability($1) }) ?? primary
    }

    /// Evaluates how well a color stands out as an emissive accent:
    /// Rewards high chromatic saturation, healthy midtone luminance (0.35-0.65), and avoids murky/washed-out tones.
    private func standoutScore(_ c: RGB) -> Double {
        let sat = c.saturation
        let lum = c.luminance
        // Peak luminance around 0.50 for rich, luminous glow
        let lumScore = 1.0 - abs(lum - 0.50) * 1.5
        // Boost vibrant colors (high saturation)
        return (sat * 2.0) + max(0.0, lumScore)
    }

    /// General suitability for ambient screen rim lighting
    private func glowSuitability(_ c: RGB) -> Double {
        let sat = c.saturation
        let lum = c.luminance
        let lumPenalty = lum < 0.10 ? (0.10 - lum) * 5.0 : (lum > 0.85 ? (lum - 0.85) * 5.0 : 0.0)
        return sat * 1.5 + (1.0 - abs(lum - 0.5)) - lumPenalty
    }

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
