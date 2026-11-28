import SwiftUI

enum LyricAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var unitPoint: UnitPoint {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

enum VisibleLinesMode: String, CaseIterable, Identifiable {
    case one
    case three
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .one: return "1 Line"
        case .three: return "3 Lines"
        case .all: return "All"
        }
    }
}

enum IdleStyle: String, CaseIterable, Identifiable {
    case cinematic
    case classic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cinematic: return "Cinematic"
        case .classic: return "Classic"
        }
    }
}


enum CinematicLook: String, CaseIterable, Identifiable {
    case album
    case monochrome
    var id: String { rawValue }
    var displayName: String { self == .album ? "Album color" : "Monochrome poster" }
}


enum CinematicGlow {
    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(3, max(0, value)) : 1
    }
}

// MARK: Island customization

enum IslandTrigger: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }
    var displayName: String { self == .hover ? "Hover" : "Click" }
}

enum IslandMotion: String, CaseIterable, Identifiable {
    case smooth
    case snappy
    case bouncy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smooth: return "Smooth"
        case .snappy: return "Snappy"
        case .bouncy: return "Bouncy"
        }
    }

    /// Opening spring. Smooth and Snappy are critically damped (no overshoot); only Bouncy
    /// overshoots, for people who want a physical feel.
    var open: Animation {
        switch self {
        case .smooth: return .spring(response: 0.38, dampingFraction: 1)
        case .snappy: return .spring(response: 0.28, dampingFraction: 1)
        case .bouncy: return .spring(response: 0.42, dampingFraction: 0.78)
        }
    }

    /// Closing spring: always critically damped so it tucks cleanly into the notch.
    var close: Animation {
        switch self {
        case .smooth: return .spring(response: 0.32, dampingFraction: 1)
        case .snappy: return .spring(response: 0.24, dampingFraction: 1)
        case .bouncy: return .spring(response: 0.34, dampingFraction: 1)
        }
    }
}

enum IslandSize: String, CaseIterable, Identifiable {
    case compact
    case regular
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .large: return "Large"
        }
    }

    /// Content size below the notch band (header row, progress, transport, padding).
    var expanded: CGSize {
        switch self {
        case .compact: return CGSize(width: 400, height: 134)
        case .regular: return CGSize(width: 450, height: 148)
        case .large: return CGSize(width: 520, height: 166)
        }
    }

    var artworkSize: CGFloat {
        switch self {
        case .compact: return 44
        case .regular: return 52
        case .large: return 62
        }
    }

    /// Previous/next and play/pause symbol sizes.
    var transportSizes: (skip: CGFloat, play: CGFloat) {
        switch self {
        case .compact: return (19, 26)
        case .regular: return (22, 30)
        case .large: return (24, 34)
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .compact: return 14
        case .regular: return 15
        case .large: return 17
        }
    }
}

// MARK: Glow customization (shared with the screensaver)

enum GlowColorMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case album
    case custom
    case spectrum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .album: return "Album"
        case .custom: return "Custom"
        case .spectrum: return "Spectrum"
        }
    }
}

enum GlowStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case orbit
    case pulse
    case steady

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .orbit: return "Orbit"
        case .pulse: return "Pulse"
        case .steady: return "Steady"
        }
    }

    /// Index passed to the edge-glow shader.
    var shaderIndex: Float {
        switch self {
        case .orbit: return 0
        case .pulse: return 1
        case .steady: return 2
        }
    }
}

/// How the edge glow looks, everywhere it's drawn (Beat Glow, idle scene, screensaver).
struct GlowAppearance: Codable, Equatable, Sendable {
    var colorMode: GlowColorMode = .album
    var customColor = RGB(r: 0.45, g: 0.62, b: 1.0)
    var style: GlowStyle = .orbit
    /// Orbit and spectrum speed multiplier, 0.25…3.
    var speed: Double = 1
    /// Width multiplier for the light's falloff, 0.5…2.5.
    var thickness: Double = 1
    /// Flare on each sung word (from lyric word timings).
    var followsLyrics = true

    static let `default` = GlowAppearance()

    /// The solid color to use with `palette` (spectrum is computed in the shader).
    func color(for palette: AlbumPalette) -> RGB {
        colorMode == .custom ? customColor : palette.dominantGlowColor
    }
}

// MARK: Surface material (shared with the screensaver)

/// What Hum's floating surfaces are made of: the island, the glass music player and the
/// lyrics window's control bar.
enum SurfaceMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case liquidGlass
    case frosted
    case solid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquidGlass: return "Liquid Glass"
        case .frosted: return "Frosted"
        case .solid: return "Solid"
        }
    }

    /// Liquid Glass needs macOS 26 or later.
    static var isLiquidGlassAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The material actually drawn: Reduce Transparency forces Solid, and Liquid Glass falls
    /// back to Frosted on systems that don't have it.
    func resolved(reduceTransparency: Bool) -> SurfaceMaterial {
        if reduceTransparency { return .solid }
        if self == .liquidGlass && !Self.isLiquidGlassAvailable { return .frosted }
        return self
    }
}
