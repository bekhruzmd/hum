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
        if status != result { status = result }
        if case .active(let state) = result { activeSourceID = state.track.player }
        if previousTrack != currentTrack {
            trackDidChange(to: currentTrack)
        }
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
            artworkImage = nil
            palette = .fallback
            return
        }
        let source = sources.first { $0.id == track.player }
        artworkTask = Task { [weak self, artworkLoader] in
            let artwork = await artworkLoader.artwork(for: track, source: source)
            guard !Task.isCancelled, let self, self.currentTrack == track else { return }
            self.artworkImage = artwork.flatMap { NSImage(data: $0.data) }
            self.palette = artwork?.palette ?? .fallback
        }
    }

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
