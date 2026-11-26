import Foundation

/// Fetches synchronized word-by-word (YRC) and line-by-line (LRC) lyrics from NetEase Cloud Music.
/// 100% free open API with extensive international, Russian, and Asian music coverage.
struct NetEaseLyricsService: Sendable {
    private static let searchURL = "http://music.163.com/api/search/get/"
    private static let lyricURL = "http://music.163.com/api/song/lyric"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Searches for the track on NetEase and returns synchronized lyrics (prefers YRC word-by-word, then LRC).
    func lyrics(for track: Track) async throws -> LyricsContent? {
        guard let songId = try await findSongId(title: track.title, artist: track.artist) else {
            return nil
        }
        return try await fetchLyrics(songId: songId)
    }

    private func findSongId(title: String, artist: String) async throws -> Int? {
        guard let url = URL(string: Self.searchURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let query = "\(title) \(artist)"
        let bodyComponents = [
            "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)",
            "type=1",
            "offset=0",
            "total=true",
            "limit=5"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]],
              let firstSong = songs.first,
              let id = firstSong["id"] as? Int else {
            return nil
        }

        return id
    }

    private func fetchLyrics(songId: Int) async throws -> LyricsContent? {
        guard var components = URLComponents(string: Self.lyricURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "id", value: String(songId)),
            URLQueryItem(name: "lv", value: "-1"),
            URLQueryItem(name: "kv", value: "-1"),
            URLQueryItem(name: "tv", value: "-1"),
            URLQueryItem(name: "yv", value: "1")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // 1. First priority: YRC word-by-word karaoke format
        if let yrc = json["yrc"] as? [String: Any],
           let lyric = yrc["lyric"] as? String, !lyric.isEmpty {
            let lines = NetEaseParser.parseYRC(lyric)
            if !lines.isEmpty {
                return .synced(lines)
            }
        }

        // 2. Second priority: Standard line-by-line LRC format
        if let lrc = json["lrc"] as? [String: Any],
           let lyric = lrc["lyric"] as? String, !lyric.isEmpty {
            let lines = LRCParser.parse(lyric)
            if !lines.isEmpty {
                return .synced(lines)
            }
        }

        return nil
    }
}
