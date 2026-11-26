import Foundation
import Observation

@Observable
@MainActor
final class NowPlayingStore {
    enum Status: Equatable {
        case nothingPlaying
        case active(PlaybackState)
        case needsPermission(MusicSource)
    }

    private(set) var status: Status = .nothingPlaying
    var preferredPlayer: PreferredPlayer = .auto

    private var pollingTask: Task<Void, Never>?
    private var appleMusicArtworkCache: [String: URL] = [:]
    private var attemptedArtworkKeys: Set<String> = []

    var currentTrack: Track? {
        if case .active(let state) = status {
            return state.track
        }
        return nil
    }

    var playbackState: PlaybackState? {
        if case .active(let state) = status {
            return state
        }
        return nil
    }

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.pollOnce()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func pollOnce() {
        switch AppleScriptReader.fetchActivePlayback(preferredPlayer: preferredPlayer) {
        case .playing(let state):
            let enrichedState = enrichAppleMusicArtwork(state)
            status = .active(enrichedState)
        case .nothingPlaying:
            status = .nothingPlaying
        case .notAuthorized(let source):
            status = .needsPermission(source)
        }
    }

    func seek(to position: TimeInterval) {
        guard case .active(let state) = status else { return }
        AppleScriptReader.seek(to: position, in: state.track.source)
        let updated = PlaybackState(
            track: state.track,
            position: max(0, position),
            isPlaying: state.isPlaying,
            fetchedAt: Date()
        )
        status = .active(updated)
    }

    private func enrichAppleMusicArtwork(_ state: PlaybackState) -> PlaybackState {
        guard state.track.source == .appleMusic, state.track.artworkURL == nil else {
            return state
        }
        let key = state.track.cacheKey
        if let cachedURL = appleMusicArtworkCache[key] {
            return withArtwork(cachedURL, in: state)
        }
        guard !attemptedArtworkKeys.contains(key) else {
            return state
        }
        attemptedArtworkKeys.insert(key)
        if let fetchedURL = AppleScriptReader.fetchAppleMusicArtworkURL(for: state.track) {
            appleMusicArtworkCache[key] = fetchedURL
            return withArtwork(fetchedURL, in: state)
        }
        return state
    }

    private func withArtwork(_ url: URL, in state: PlaybackState) -> PlaybackState {
        let updatedTrack = Track(
            title: state.track.title,
            artist: state.track.artist,
            album: state.track.album,
            duration: state.track.duration,
            artworkURL: url,
            source: state.track.source
        )
        return PlaybackState(
            track: updatedTrack,
            position: state.position,
            isPlaying: state.isPlaying,
            fetchedAt: state.fetchedAt
        )
    }
}
