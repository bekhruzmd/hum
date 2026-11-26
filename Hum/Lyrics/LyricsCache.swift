import CryptoKit
import Foundation

/// Lyrics cache in memory and on disk (`~/Library/Application Support/<bundle id>/Lyrics`),
/// keyed by `Track.cacheKey` (title|artist|duration).
///
/// "Not found" results expire after `notFoundTTL` so newly uploaded lyrics show up later.
actor LyricsCache {
    private struct Entry: Codable {
        let content: LyricsContent
        let savedAt: Date
    }

    static let notFoundTTL: TimeInterval = 24 * 60 * 60

    private var memory: [String: Entry] = [:]
    private let directory: URL?
    private let now: @Sendable () -> Date

    /// - Parameter directory: where to store files; nil for memory only.
    init(directory: URL? = LyricsCache.defaultDirectory, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Hum", isDirectory: true)
            .appendingPathComponent("Lyrics", isDirectory: true)
    }

    func content(for key: String) -> LyricsContent? {
        let entry = memory[key] ?? readDisk(key)
        guard let entry else { return nil }
        if entry.content == .notFound, now().timeIntervalSince(entry.savedAt) > Self.notFoundTTL {
            remove(key)
            return nil
        }
        memory[key] = entry
        return entry.content
    }

    func store(_ content: LyricsContent, for key: String) {
        let entry = Entry(content: content, savedAt: now())
        memory[key] = entry
        guard let url = fileURL(for: key), let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func remove(_ key: String) {
        memory[key] = nil
        if let url = fileURL(for: key) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func readDisk(_ key: String) -> Entry? {
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    private func fileURL(for key: String) -> URL? {
        guard let directory else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest).appendingPathExtension("json")
    }
}
