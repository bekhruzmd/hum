import Foundation

/// One LRCLIB record (from `/api/get` or `/api/search`).
struct LRCLibRecord: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

/// Multi-provider lyrics service: queries LRCLIB first, then automatically falls back to
/// NetEase Cloud Music for word-by-word (YRC) and line-synced (LRC) lyrics across international and Russian catalogs.
struct LyricsService: Sendable {
    static let userAgent = "Hum/0.1 (https://github.com/yourname/hum)"
    private static let base = "https://lrclib.net/api"

    let session: URLSession
    let netEase: NetEaseLyricsService

    init(session: URLSession = .shared) {
        self.session = session
        self.netEase = NetEaseLyricsService(session: session)
    }

    /// Queries NetEase and LRCLIB concurrently.
    /// Prioritizes word-by-word (YRC) karaoke timing, then synced lines, then plain text.
    func lyrics(for track: Track) async throws -> LyricsContent {
        async let netEaseTask = (try? await netEase.lyrics(for: track))
        async let lrclibTask = fetchFromLRCLib(track)

        let (netEaseContent, lrclibContent) = await (netEaseTask, lrclibTask)

        // 1. If NetEase provided syllable/word-by-word synced lyrics, prioritize it for rich karaoke timing
        if let netEaseContent, case .synced(let lines) = netEaseContent, lines.contains(where: { !$0.words.isEmpty }) {
            return netEaseContent
        }

        // 2. If LRCLIB has synced lyrics, use it
        if let lrclibContent, case .synced = lrclibContent {
            return lrclibContent
        }

        // 3. Fallback to NetEase line-synced lyrics (e.g. Russian / foreign catalog songs where LRCLIB 404s)
        if let netEaseContent, case .synced = netEaseContent {
            return netEaseContent
        }

        // 4. Fallback to LRCLIB plain / instrumental
        if let lrclibContent, lrclibContent != .notFound {
            return lrclibContent
        }

        // 5. Fallback to NetEase plain if available
        if let netEaseContent, netEaseContent != .notFound {
            return netEaseContent
        }

        return .notFound
    }

    private func fetchFromLRCLib(_ track: Track) async -> LyricsContent? {
        if let exact = try? await get(track) {
            let content = Self.content(from: exact)
            if content != .notFound { return content }
        }
        if let results = try? await search(title: track.title, artist: track.artist) {
            if let match = results.first(where: { abs(($0.duration ?? -100) - track.duration) <= 2 }) {
                let content = Self.content(from: match)
                if content != .notFound { return content }
            }
        }
        return nil
    }

    func search(title: String, artist: String) async throws -> [LRCLibRecord] {
        let items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let data = try await request("search", items, allow404: false) else { return [] }
        return try JSONDecoder().decode([LRCLibRecord].self, from: data)
    }

    private func get(_ track: Track) async throws -> LRCLibRecord? {
        let items = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        guard let data = try await request("get", items, allow404: true) else { return nil }
        return try JSONDecoder().decode(LRCLibRecord.self, from: data)
    }

    private func request(_ path: String, _ items: [URLQueryItem], allow404: Bool) async throws -> Data? {
        guard var components = URLComponents(string: "\(Self.base)/\(path)") else { throw URLError(.badURL) }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404, allow404 { return nil }
        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    /// Prefers synced lyrics, then plain, then instrumental.
    static func content(from record: LRCLibRecord) -> LyricsContent {
        if let synced = record.syncedLyrics {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = record.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
            return .plain(plain)
        }
        if record.instrumental == true { return .instrumental }
        return .notFound
    }
}
