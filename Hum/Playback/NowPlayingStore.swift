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

    private var pollingTask: Task<Void, Never>?

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
        switch AppleScriptReader.fetchActivePlayback() {
        case .playing(let state):
            status = .active(state)
        case .nothingPlaying:
            status = .nothingPlaying
        case .notAuthorized(let source):
            status = .needsPermission(source)
        }
    }
}
