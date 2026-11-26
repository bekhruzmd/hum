import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let time: TimeInterval
    let text: String
}

enum LyricsContent: Equatable, Sendable {
    case synced([LyricLine])
    case plain(String)
    case instrumental
    case notFound
}
