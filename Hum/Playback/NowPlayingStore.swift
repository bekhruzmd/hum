import AppKit
import Foundation
import Observation

/// The single source of truth for what's playing. Owns the app's only playback poll timer.
@Observable
@MainActor
final class NowPlayingStore {
    enum Status: Equatable {
        case nothingPlaying
        case active(PlaybackState)
        case needsPermission(PlayerApp)
    }

    private(set) var status: Status = .nothingPlaying
    private(set) var artworkImage: NSImage?
    /// The encoded cover bytes behind `artworkImage` (for the screensaver feed).
    @ObservationIgnored private(set) var artworkData: Data?
    private(set) var palette: AlbumPalette = .fallback

    var preferredPlayer: PreferredPlayer = .auto {
        didSet { if oldValue != preferredPlayer { Task { await refresh() } } }
    }

    /// Called whenever the track identity changes (including to nil).
    @ObservationIgnored var onTrackChange: ((Track?) -> Void)?

    @ObservationIgnored private let sources: [any PlaybackSource]
    @ObservationIgnored private let artworkLoader: ArtworkLoader
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var activeSourceID: PlayerApp?
    /// Set after a local seek/control so a stale poll result doesn't snap the UI back.
    @ObservationIgnored private var suppressPollUntil: Date = .distantPast

    init(
        sources: [any PlaybackSource] = [SpotifySource(), MusicSource()],
        artworkLoader: ArtworkLoader = ArtworkLoader()
    ) {
        self.sources = sources
        self.artworkLoader = artworkLoader
    }

    var playbackState: PlaybackState? {
        if case .active(let state) = status { return state }
        return nil
    }

    var currentTrack: Track? { playbackState?.track }
    var isPlaying: Bool { playbackState?.isPlaying ?? false }

    // MARK: Polling

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        let result = await Self.readBest(from: sources, preferred: preferredPlayer)
        guard Date() >= suppressPollUntil else { return }
        apply(result)
    }

    private func apply(_ result: Status) {
        let previousTrack = currentTrack
        let next = Self.smoothed(current: status, incoming: result)
        if status != next { status = next }
        if case .active(let state) = result { activeSourceID = state.track.player }
        if previousTrack != currentTrack {
            trackDidChange(to: currentTrack)
        }
    }

    /// Keeps the existing clock anchor when a poll agrees with our interpolation.
    ///
    /// AppleScript positions jitter by tens of milliseconds; re-anchoring every second makes
    /// word fills and the scrubber twitch, and re-renders every observer. Only a real jump
    /// (seek, buffering, scrubbing in the player) beyond the tolerance re-anchors.
    nonisolated static func smoothed(current: Status, incoming: Status) -> Status {
        guard
            case .active(let old) = current, case .active(let new) = incoming,
            old.track == new.track, old.isPlaying == new.isPlaying
        else { return incoming }
        let drift = abs(old.interpolatedPosition(at: new.fetchedAt) - new.position)
        let tolerance: TimeInterval = new.isPlaying ? 0.3 : 0.05
        return drift < tolerance ? current : incoming
    }

    /// Picks the playing source first, then any paused source with a track.
    private static func readBest(from sources: [any PlaybackSource], preferred: PreferredPlayer) async -> Status {
        var paused: PlaybackState?
        var unauthorized: PlayerApp?
        for source in sources where preferred.allows(source.id) && source.isRunning {
            do {
                guard let state = try await source.current() else { continue }
                if state.isPlaying { return .active(state) }
                paused = paused ?? state
            } catch PlaybackSourceError.notAuthorized(let app) {
                unauthorized = unauthorized ?? app
            } catch {
                continue
            }
        }
        if let paused { return .active(paused) }
        if let unauthorized { return .needsPermission(unauthorized) }
        return .nothingPlaying
    }

    // MARK: Artwork

    private func trackDidChange(to track: Track?) {
        onTrackChange?(track)
        artworkTask?.cancel()
        guard let track else {
            artworkData = nil
            artworkImage = nil
            palette = .fallback
            return
        }
        let source = sources.first { $0.id == track.player }
        artworkTask = Task { [weak self, artworkLoader] in
            let artwork = await artworkLoader.artwork(for: track, source: source)
            guard !Task.isCancelled, let self, self.currentTrack == track else { return }
            self.artworkData = artwork?.data
            self.artworkImage = artwork.flatMap { NSImage(data: $0.data) }
            self.palette = artwork?.palette ?? .fallback
        }
    }

    #if DEBUG
    /// Injects a state for previews and snapshot tests.
    func setPreviewState(_ state: PlaybackState?, artwork: NSImage? = nil, palette: AlbumPalette = .fallback) {
        status = state.map(Status.active) ?? .nothingPlaying
        artworkImage = artwork
        self.palette = palette
    }
    #endif

    // MARK: Controls

    private var activeSource: (any PlaybackSource)? {
        sources.first { $0.id == activeSourceID }
    }

    func playPause() {
        guard let source = activeSource, let state = playbackState else { return }
        let position = state.interpolatedPosition()
        setOptimistic(state.with(position: position, isPlaying: !state.isPlaying))
        Task { await source.playPause() }
    }

    func nextTrack() {
        guard let source = activeSource else { return }
        Task {
            await source.nextTrack()
            await refresh()
        }
    }

    func previousTrack() {
        guard let source = activeSource else { return }
        Task {
            await source.previousTrack()
            await refresh()
        }
    }

    func seek(to position: TimeInterval) {
        guard let source = activeSource, let state = playbackState else { return }
        setOptimistic(state.with(position: max(0, position)))
        Task { await source.seek(to: position) }
    }

    private func setOptimistic(_ state: PlaybackState) {
        status = .active(state)
        suppressPollUntil = Date().addingTimeInterval(0.8)
    }
}
