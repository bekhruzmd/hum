import Foundation
import Observation

@Observable
@MainActor
final class LyricsStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded(LyricsContent)
        case error(String)
    }

    private(set) var state: State = .idle

    private var cache: [String: LyricsContent] = [:]
    private var currentTrackKey: String?
    private var fetchTask: Task<Void, Never>?

    func update(for track: Track?) {
        guard let track else {
            fetchTask?.cancel()
            fetchTask = nil
            currentTrackKey = nil
            state = .idle
            return
        }

        let key = track.cacheKey
        guard key != currentTrackKey else { return }

        currentTrackKey = key
        fetchTask?.cancel()

        if let cached = cache[key] {
            state = .loaded(cached)
            return
        }

        state = .loading
        fetchTask = Task { [weak self] in
            do {
                let content = try await LRCLibClient.fetchLyrics(for: track)
                guard !Task.isCancelled else { return }
                self?.cache[key] = content
                self?.state = .loaded(content)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .error("Could not load lyrics.")
            }
        }
    }
}
