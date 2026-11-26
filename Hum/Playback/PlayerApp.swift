import Foundation

/// The music apps Hum can read from via AppleScript.
enum PlayerApp: String, Sendable, Codable, CaseIterable, Hashable {
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }

    /// Name used in `tell application "…"` blocks.
    var scriptingName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }
}

/// User preference for which player Hum follows.
enum PreferredPlayer: String, CaseIterable, Identifiable, Sendable {
    case auto
    case spotify
    case appleMusic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    func allows(_ app: PlayerApp) -> Bool {
        switch self {
        case .auto: return true
        case .spotify: return app == .spotify
        case .appleMusic: return app == .appleMusic
        }
    }
}
