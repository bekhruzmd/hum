import AppKit
import Observation
import OSLog

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
    @ObservationIgnored private let logger = Logger(subsystem: "com.yourname.hum", category: "SaverReader")
    @ObservationIgnored private var didLogConnection = false

    /// Do not use Foundation's container-relative Application Support URL here.
    private let directory = ScreensaverFeed.directory()

    var sceneData: CinematicSceneData {
        guard let feed else { return CinematicSceneData(statusMessage: "Open Hum to connect your music") }
        if feed.sharingEnabled == false {
            return CinematicSceneData(statusMessage: "Enable screensaver sharing in Hum settings")
        }
        return CinematicSceneData(
            track: feed.track,
            artwork: artwork,
            palette: feed.palette,
            lines: feed.lines,
            effect: feed.effectKind,
            look: feed.cinematicLook,
            edgeGlow: feed.edgeGlowIntensity,
            displayEdgeProfiles: feed.displayEdgeProfiles ?? [:],
            isPlaying: feed.isPlaying,
            isShuffling: feed.isShuffling,
            playbackPosition: { feed.playbackPosition(at: $0) },
            lyricTime: { feed.lyricTime(at: $0) }
        )
    }

    /// Actions that the screensaver's MusicBar can trigger. Each writes a command file
    /// that Hum picks up and executes.
    func remoteActions() -> MusicBarActions {
        MusicBarActions(
            playPause: { ScreensaverCommand.send(.playPause) },
            previous: { ScreensaverCommand.send(.previous) },
            next: { ScreensaverCommand.send(.next) },
            seek: { position in ScreensaverCommand.send(.seek, seekPosition: position) },
            shuffle: { ScreensaverCommand.send(.shuffle) },
            openPlayer: { /* Can't activate apps from the saver process */ },
            playerName: feed?.track?.artist ?? "music player"
        )
    }

    func start() {
        guard task == nil else { return }
        isRunning = true
        reload()
        let build = Bundle(for: SaverModel.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        logger.notice("Screensaver started; shared-home transport v2; build=\(build, privacy: .public)")
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                self.reload()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func reload() {
        if let feed, !feed.isFresh(at: Date()) {
            self.feed = nil
            artwork = nil
            loadedArtworkFile = nil
            lastModified = nil
            didLogConnection = false
            logger.notice("Screensaver feed expired; waiting for Hum")
        }
        let file = directory.appendingPathComponent(ScreensaverFeed.fileName)
        let modified = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
        guard let modified, modified != lastModified else { return }
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode(ScreensaverFeed.self, from: data),
              decoded.version == ScreensaverFeed.currentVersion,
              decoded.isFresh(at: Date())
        else { return }
        if !didLogConnection || feed?.track != decoded.track || feed?.isPlaying != decoded.isPlaying
            || feed?.lines.count != decoded.lines.count {
            logger.notice("Screensaver connected to Hum feed; playing=\(decoded.isPlaying), lyricLines=\(decoded.lines.count), anchor=\(decoded.anchorDate)")
            didLogConnection = true
        }
        lastModified = modified
        if decoded.artworkFile != loadedArtworkFile || artwork == nil {
            loadedArtworkFile = decoded.artworkFile
            artwork = decoded.artworkFile.flatMap { NSImage(contentsOf: directory.appendingPathComponent($0)) }
        }
        feed = decoded
    }
}
