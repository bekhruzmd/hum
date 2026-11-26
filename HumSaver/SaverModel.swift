import AppKit
import Observation

/// Reads the feed Hum writes (see `ScreensaverFeed`) about once a second, only re-decoding
/// when the file actually changed.
@Observable
@MainActor
final class SaverModel {
    private(set) var feed: ScreensaverFeed?
    private(set) var artwork: NSImage?
    private(set) var isRunning = false

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastModified: Date?
    @ObservationIgnored private var loadedArtworkFile: String?

    /// Inside the sandboxed screensaver host this resolves to its own container.
    private var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(ScreensaverFeed.folderName, isDirectory: true)
    }

    var sceneData: CinematicSceneData {
        guard let feed else { return CinematicSceneData() }
        return CinematicSceneData(
            track: feed.track,
            artwork: artwork,
            palette: feed.palette,
            lines: feed.lines,
            effect: feed.effectKind,
            isPlaying: feed.isPlaying,
            lyricTime: { feed.lyricTime(at: $0) }
        )
    }

    func start() {
        guard task == nil else { return }
        isRunning = true
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.reload()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func reload() {
        guard let directory else { return }
        let file = directory.appendingPathComponent(ScreensaverFeed.fileName)
        let modified = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
        guard let modified, modified != lastModified else { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode(ScreensaverFeed.self, from: data),
              decoded.version == ScreensaverFeed.currentVersion
        else { return }
        if decoded.artworkFile != loadedArtworkFile {
            loadedArtworkFile = decoded.artworkFile
            artwork = decoded.artworkFile.flatMap { NSImage(contentsOf: directory.appendingPathComponent($0)) }
        }
        feed = decoded
    }
}
