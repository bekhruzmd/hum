import Foundation
import Observation

/// Lyrics for the current track. Fetches only on track change and cancels stale fetches.
@Observable
@MainActor
final class LyricsStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded(LyricsContent)
        case error(String)
    }

    private(set) var state: State = .idle {
        didSet { rebuildTimedLines() }
    }
    private(set) var track: Track?
    /// Synced lines with word timings, rebuilt whenever `state` changes.
    private(set) var timedLines: [TimedLine] = []

    @ObservationIgnored private let service: LyricsService
    @ObservationIgnored private let cache: LyricsCache
    @ObservationIgnored private var fetchTask: Task<Void, Never>?

    init(service: LyricsService = LyricsService(), cache: LyricsCache = LyricsCache()) {
        self.service = service
        self.cache = cache
    }

    var syncedLines: [LyricLine]? {
        if case .loaded(.synced(let lines)) = state { return lines }
        return nil
    }

    private func rebuildTimedLines() {
        if case .loaded(.synced(let lines)) = state {
            timedLines = WordTimingEstimator.timedLines(from: lines, trackDuration: track?.duration ?? 0)
        } else if !timedLines.isEmpty {
            timedLines = []
        }
    }

    func update(for newTrack: Track?) {
        guard newTrack?.cacheKey != track?.cacheKey else { return }
        track = newTrack
        fetchTask?.cancel()
        guard let newTrack else {
            state = .idle
            return
        }
        state = .loading
        fetchTask = Task { [weak self, service, cache] in
            let key = newTrack.cacheKey
            if let cached = await cache.content(for: key) {
                guard !Task.isCancelled else { return }
                self?.state = .loaded(cached)
                return
            }
            do {
                let content = try await service.lyrics(for: newTrack)
                guard !Task.isCancelled else { return }
                await cache.store(content, for: key)
                self?.state = .loaded(content)
            } catch {
                guard !Task.isCancelled else { return }
                let offline = (error as? URLError)?.code == .notConnectedToInternet
                self?.state = .error(offline ? "You're offline." : "LRCLIB didn't respond. Try again later.")
            }
        }
    }

    /// Replaces the lyrics for the current track (manual pick or .lrc import) and caches them.
    func override(with content: LyricsContent) {
        guard let track else { return }
        fetchTask?.cancel()
        state = .loaded(content)
        let key = track.cacheKey
        Task { [cache] in await cache.store(content, for: key) }
    }

    /// Drops the cached entry and fetches again.
    func reload() {
        guard let current = track else { return }
        let key = current.cacheKey
        track = nil
        Task { [cache] in
            await cache.remove(key)
            self.update(for: current)
        }
    }
}
