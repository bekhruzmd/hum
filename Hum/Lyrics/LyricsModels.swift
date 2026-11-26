import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let time: TimeInterval
    let text: String

    /// Text to show; empty LRC lines (instrumental breaks) render as a note.
    var displayText: String { text.isEmpty ? "♪" : text }
}

enum LyricsContent: Equatable, Sendable {
    case synced([LyricLine])
    case plain(String)
    case instrumental
    case notFound
}
