import AppKit
import CryptoKit
import Foundation

/// Keeps the Hum screensaver's feed up to date (see `ScreensaverFeed`).
///
/// Writes only on real changes (track, play/pause, seek, lyrics, cover, offset), never on a
/// timer. Hum writes into the screensaver host's container only if that container already
/// exists: creating another app's container by hand can stop macOS from launching it.
@MainActor
final class ScreensaverFeedWriter {
    /// The sandboxed host that runs third-party screensavers (and its Intel twin on Apple silicon).
    static let hostContainerIDs = [
        "com.apple.ScreenSaver.Engine.legacyScreenSaver",
        "com.apple.ScreenSaver.Engine.legacyScreenSaver.x86-64"
    ]

    private unowned let environment: AppEnvironment
    private var lastFeed: ScreensaverFeed?
    private var lastArtworkFile: String?
    private var pendingWrite: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        observeContinuously(self) { writer in
            guard writer.environment.settings.screensaverFeed else { return }
            let feed = writer.makeFeed()
            writer.schedule(feed)
        }
    }

    /// Folders the screensaver might read from: each existing host container, plus the
    /// regular Application Support folder (used if the host ever runs unsandboxed).
    static func targetDirectories(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let fileManager = FileManager.default
        var directories = hostContainerIDs.compactMap { id -> URL? in
            let support = home
                .appendingPathComponent("Library/Containers/\(id)/Data/Library/Application Support", isDirectory: true)
            return fileManager.fileExists(atPath: support.path) ? support : nil
        }
        directories.append(home.appendingPathComponent("Library/Application Support", isDirectory: true))
        return directories.map { $0.appendingPathComponent(ScreensaverFeed.folderName, isDirectory: true) }
    }

    private func makeFeed() -> ScreensaverFeed {
        let nowPlaying = environment.nowPlaying
        let state = nowPlaying.playbackState
        let now = Date()
        return ScreensaverFeed(
            track: state.map { SceneTrackInfo(title: $0.track.title, artist: $0.track.artist, album: $0.track.album) },
            lyricAnchor: state.map { environment.lyricTime($0, at: now) } ?? 0,
            anchorDate: now.timeIntervalSince1970,
            isPlaying: state?.isPlaying ?? false,
            palette: nowPlaying.palette,
            lines: environment.lyrics.timedLines,
            effect: environment.settings.cinematicEffect.rawValue,
            artworkFile: nowPlaying.artworkImage == nil ? nil : nowPlaying.artworkData.map(Self.artworkFileName)
        )
    }

    /// Coalesces bursts of changes into one write.
    private func schedule(_ feed: ScreensaverFeed) {
        pendingWrite?.cancel()
        pendingWrite = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            self.write(feed)
        }
    }

    private func write(_ feed: ScreensaverFeed) {
        guard feed != lastFeed, let json = try? JSONEncoder().encode(feed) else { return }
        let artwork = environment.nowPlaying.artworkData
        for directory in Self.targetDirectories() {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? json.write(to: directory.appendingPathComponent(ScreensaverFeed.fileName), options: .atomic)
            if let name = feed.artworkFile, name != lastArtworkFile, let artwork {
                removeOldArtwork(in: directory, keeping: name)
                try? artwork.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        }
        lastFeed = feed
        lastArtworkFile = feed.artworkFile
    }

    private func removeOldArtwork(in directory: URL, keeping name: String) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where file.hasPrefix("artwork-") && file != name {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    static func artworkFileName(for data: Data) -> String {
        let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "artwork-\(digest).img"
    }
}

/// Installs the bundled Hum.saver into ~/Library/Screen Savers.
@MainActor
enum ScreensaverInstaller {
    enum InstallError: LocalizedError {
        case missingBundle

        var errorDescription: String? { "Hum.saver isn't inside this copy of Hum. Rebuild the app." }
    }

    static var destination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers", isDirectory: true)
            .appendingPathComponent("Hum.saver", isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: destination.path)
    }

    static func install() throws {
        guard let source = Bundle.main.url(forResource: "Hum", withExtension: "saver") else {
            throw InstallError.missingBundle
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    static func openScreenSaverSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
