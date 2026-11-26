import CryptoKit
import Foundation

struct Artwork: Sendable, Equatable {
    let data: Data
    let palette: AlbumPalette
}

/// Loads cover art and its palette, cached per album in memory and on disk
/// (`~/Library/Caches/<bundle id>/Artwork`).
actor ArtworkLoader {
    private var memory: [String: Artwork] = [:]
    private var memoryOrder: [String] = []
    private let memoryLimit = 24
    private let directory: URL
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = caches
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Hum", isDirectory: true)
            .appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func artwork(for track: Track, source: (any PlaybackSource)?) async -> Artwork? {
        let key = track.albumKey
        if let cached = memory[key] { return cached }
        if let disk = loadFromDisk(key: key) {
            remember(disk, key: key)
            return disk
        }

        guard let data = await fetchData(for: track, source: source), !Task.isCancelled else { return nil }
        let artwork = Artwork(data: data, palette: ColorExtractor.palette(from: data) ?? .fallback)
        remember(artwork, key: key)
        saveToDisk(artwork, key: key)
        return artwork
    }

    private func fetchData(for track: Track, source: (any PlaybackSource)?) async -> Data? {
        if let url = track.artworkURL {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            guard
                let (data, response) = try? await session.data(for: request),
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else { return nil }
            return data
        }
        return await source?.artworkData()
    }

    private func remember(_ artwork: Artwork, key: String) {
        memory[key] = artwork
        memoryOrder.removeAll { $0 == key }
        memoryOrder.append(key)
        while memoryOrder.count > memoryLimit {
            memory[memoryOrder.removeFirst()] = nil
        }
    }

    private func fileStem(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    private func loadFromDisk(key: String) -> Artwork? {
        let stem = fileStem(for: key)
        guard
            let data = try? Data(contentsOf: stem.appendingPathExtension("img")),
            let paletteData = try? Data(contentsOf: stem.appendingPathExtension("json")),
            let palette = try? JSONDecoder().decode(AlbumPalette.self, from: paletteData)
        else { return nil }
        return Artwork(data: data, palette: palette)
    }

    private func saveToDisk(_ artwork: Artwork, key: String) {
        let stem = fileStem(for: key)
        try? artwork.data.write(to: stem.appendingPathExtension("img"), options: .atomic)
        if let json = try? JSONEncoder().encode(artwork.palette) {
            try? json.write(to: stem.appendingPathExtension("json"), options: .atomic)
        }
    }
}
