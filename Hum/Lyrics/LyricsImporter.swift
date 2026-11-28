import Foundation

/// Reads lyrics dropped onto Hum: timed LRC becomes synced lyrics, anything else plain text.
enum LyricsImporter {
    static let acceptedExtensions: Set<String> = ["lrc", "txt"]
    /// Lyrics files are small; refuse anything that clearly isn't one.
    static let maxBytes = 512 * 1024

    static func canImport(_ url: URL) -> Bool {
        acceptedExtensions.contains(url.pathExtension.lowercased())
    }

    static func content(from url: URL) -> LyricsContent? {
        guard canImport(url),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxBytes,
              let data = try? Data(contentsOf: url)
        else { return nil }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return content(from: text)
    }

    static func content(from text: String) -> LyricsContent? {
        let lines = LRCParser.parse(text)
        if !lines.isEmpty { return .synced(lines) }
        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : .plain(plain)
    }
}
