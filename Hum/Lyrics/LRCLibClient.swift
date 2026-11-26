import Foundation

struct LRCLibResponse: Decodable, Sendable {
    let syncedLyrics: String?
    let plainLyrics: String?
    let instrumental: Bool?
    let duration: Double?
}

enum LRCLibClient {
    private static let baseURL = "https://lrclib.net/api"
    private static let userAgent = "Hum/0.1 (https://github.com/yourname/hum)"

    static func fetchLyrics(for track: Track) async throws -> LyricsContent {
        if let direct = try await fetchDirect(track: track) {
            return mapResponse(direct)
        }
        if let searched = try await fetchBySearch(track: track) {
            return mapResponse(searched)
        }
        return .notFound
    }

    private static func fetchDirect(track: Track) async throws -> LRCLibResponse? {
        var components = URLComponents(string: "\(baseURL)/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 {
            return nil
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LRCLibResponse.self, from: data)
    }

    private static func fetchBySearch(track: Track) async throws -> LRCLibResponse? {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        let results = try JSONDecoder().decode([LRCLibResponse].self, from: data)
        return results.first { item in
            guard let itemDuration = item.duration else { return false }
            return abs(itemDuration - track.duration) <= 2.0
        }
    }

    private static func mapResponse(_ response: LRCLibResponse) -> LyricsContent {
        if response.instrumental == true {
            return .instrumental
        }

        if let synced = response.syncedLyrics,
           !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty {
                return .synced(lines)
            }
        }

        if let plain = response.plainLyrics,
           !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .plain(plain)
        }

        return .notFound
    }
}
