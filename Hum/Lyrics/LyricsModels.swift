import Foundation

/// One word with its start time, from Enhanced LRC `<mm:ss.xx>` tags or estimated.
struct LyricWord: Equatable, Sendable, Codable {
    let time: TimeInterval
    /// The word including any trailing whitespace, so joining words rebuilds the line.
    let text: String
}

struct LyricLine: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    let time: TimeInterval
    let text: String
    /// Word timings from Enhanced LRC. Empty when the source has none.
    var words: [LyricWord] = []
    /// End time from a trailing Enhanced LRC tag (`…word <01:02.30>`), if present.
    var endTime: TimeInterval?

    /// Text to show; empty LRC lines (instrumental breaks) render as a note.
    var displayText: String { text.isEmpty ? "♪" : text }
}

enum LyricsContent: Equatable, Sendable, Codable {
    case synced([LyricLine])
    case plain(String)
    case instrumental
    case notFound
}
