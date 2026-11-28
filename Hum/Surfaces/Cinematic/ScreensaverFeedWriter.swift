import AppKit
import CryptoKit
import Foundation
import OSLog
import Observation

/// Keeps the Hum screensaver's feed up to date (see `ScreensaverFeed`).
///
/// Publishes changes immediately and refreshes a heartbeat every five seconds. Both
/// processes use the user's real Application Support folder, without cross-container writes.
@Observable
@MainActor
final class ScreensaverFeedWriter {
    private(set) var deliveryError: String?

    @ObservationIgnored private unowned let environment: AppEnvironment
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var commandWatcher: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.yourname.hum", category: "ScreensaverFeed")
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        guard heartbeat == nil else { return }
        observeContinuously(self) { writer in
            writer.schedule(writer.currentFeed())
        }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                self.write(self.currentFeed())
            }
        }
        // Poll command queue at 10 Hz (100ms) for snappy, near-instant responsiveness
        commandWatcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { return }
                self.consumeCommand()
            }
        }
    }

    /// One shared location, readable by the saver host without modifying its protected container.
    static func targetDirectories(home: URL = ScreensaverFeed.realHomeDirectory) -> [URL] {
        [ScreensaverFeed.directory(home: home)]
    }

    private func currentFeed() -> ScreensaverFeed {
        guard environment.settings.screensaverFeed else {
            return ScreensaverFeed(sharingEnabled: false, anchorDate: Date().timeIntervalSince1970)
        }
        return makeFeed()
    }

    private func makeFeed() -> ScreensaverFeed {
        let nowPlaying = environment.nowPlaying
        let state = nowPlaying.playbackState
        let now = Date()
        return ScreensaverFeed(
            sharingEnabled: true,
            track: state.map { SceneTrackInfo(title: $0.track.title, artist: $0.track.artist, album: $0.track.album, duration: $0.track.duration) },
            lyricAnchor: state.map { environment.lyricTime($0, at: now) } ?? 0,
            anchorDate: now.timeIntervalSince1970,
            isPlaying: state?.isPlaying ?? false,
            playbackAnchor: state?.interpolatedPosition(at: now),
            isShuffling: state?.isShuffling,
            palette: nowPlaying.palette,
            lines: environment.lyrics.timedLines,
            effect: environment.settings.cinematicEffect.rawValue,
            look: environment.settings.cinematicLook.rawValue,
            edgeGlow: environment.settings.cinematicEdgeGlow,
            displayEdgeProfiles: environment.settings.displayEdgeProfiles,
            glowAppearance: environment.settings.glowAppearance,
            playerBar: environment.settings.idlePlayerBar,
            material: environment.settings.surfaceMaterial,
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
            self.consumeCommand()
        }
    }

    /// Reads and executes a command from the screensaver, if one was written.
    private func consumeCommand() {
        guard let command = ScreensaverCommand.consume() else { return }
        let nowPlaying = environment.nowPlaying
        switch command.action {
        case .playPause: nowPlaying.playPause()
        case .next: nowPlaying.nextTrack()
        case .previous: nowPlaying.previousTrack()
        case .shuffle: nowPlaying.toggleShuffle()
        case .seek:
            if let position = command.seekPosition { nowPlaying.seek(to: position) }
        }
    }

    private func write(_ feed: ScreensaverFeed) {
        guard let json = try? JSONEncoder().encode(feed) else { return }
        let artwork = environment.nowPlaying.artworkData
        var failed = false
        for directory in Self.targetDirectories() {
            do {
                try Self.publish(feed: feed, json: json, artwork: artwork, to: directory)
                if let name = feed.artworkFile { removeOldArtwork(in: directory, keeping: name) }
            } catch {
                failed = true
                logger.error("Screensaver feed write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        deliveryError = failed
            ? "Hum couldn't save the current song for the screensaver. Check that your Library/Application Support folder is writable."
            : nil
    }

    /// Publish the cover before the JSON so readers never see a reference to a missing file.
    static func publish(feed: ScreensaverFeed, json: Data, artwork: Data?, to directory: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if let name = feed.artworkFile {
            let file = directory.appendingPathComponent(name)
            if !fm.fileExists(atPath: file.path), let artwork {
                try artwork.write(to: file, options: .atomic)
            }
        }
        try json.write(to: directory.appendingPathComponent(ScreensaverFeed.fileName), options: .atomic)
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
        try replaceBundle(from: source, at: destination)
    }

    /// Stage a complete bundle before replacing the installed copy, and roll back on failure.
    static func replaceBundle(from source: URL, at destination: URL) throws {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".Hum-stage-" + UUID().uuidString)
        let backup = parent.appendingPathComponent(".Hum-backup-" + UUID().uuidString)
        try fm.copyItem(at: source, to: staging)
        defer { try? fm.removeItem(at: staging) }
        let hadPrevious = fm.fileExists(atPath: destination.path)
        if hadPrevious { try fm.moveItem(at: destination, to: backup) }
        do {
            try fm.moveItem(at: staging, to: destination)
        } catch {
            if hadPrevious { try? fm.moveItem(at: backup, to: destination) }
            throw error
        }
        if hadPrevious { try? fm.removeItem(at: backup) }
    }

    private static let screenSaverPaneID = "com.apple.ScreenSaver-Settings.extension"
    private static let wallpaperPaneID = "com.apple.Wallpaper-Settings.extension"

    /// Recent macOS versions have no separate Screen Saver pane; screensavers live under
    /// Wallpaper. Open whichever pane this system actually has.
    static var hasScreenSaverPane: Bool {
        let directory = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions", isDirectory: true)
        let bundles = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return bundles.contains { Bundle(url: $0)?.bundleIdentifier == screenSaverPaneID }
    }

    /// Where to find Hum after installing, in this macOS version's words.
    static var settingsLocation: String {
        hasScreenSaverPane
            ? "System Settings › Screen Saver"
            : "System Settings › Wallpaper, in the Screen Saver section"
    }

    static func openScreenSaverSettings() {
        let pane = hasScreenSaverPane ? screenSaverPaneID : wallpaperPaneID
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
