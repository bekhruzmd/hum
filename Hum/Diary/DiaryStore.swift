import Foundation
import Observation
import SwiftData

/// Tracks listening and logs a `Play` once the threshold is met: 30 s or 50% of the track
/// duration, whichever comes first. All data stays on-device.
@Observable
@MainActor
final class DiaryStore {
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var currentTrack: Track?
    @ObservationIgnored private var listenStart: Date?
    @ObservationIgnored private var accumulatedSeconds: TimeInterval = 0
    @ObservationIgnored private var logged = false
    @ObservationIgnored private var lastPollDate: Date?

    /// Whether the diary is enabled (matches the Settings toggle).
    var isEnabled = true

    /// The model container for SwiftData queries from views.
    var container: ModelContainer? { modelContainer }

    func start() {
        guard modelContainer == nil else { return }
        do {
            let schema = Schema([Play.self])
            let configuration = ModelConfiguration("HumDiary", isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("[Hum] Failed to create SwiftData container: \(error)")
        }
    }

    /// Called every poll cycle with the current playback state. Accumulates listening time
    /// and logs a `Play` once the threshold is met.
    func update(playbackState: PlaybackState?) {
        guard isEnabled else { return }
        guard let state = playbackState, state.isPlaying else {
            // Paused or nothing playing: keep the accumulated time but stop counting.
            lastPollDate = nil
            return
        }

        let track = state.track
        let now = Date()

        // Track changed: finalize previous and start fresh.
        if track != currentTrack {
            finalizeIfNeeded()
            currentTrack = track
            listenStart = now
            accumulatedSeconds = 0
            logged = false
            lastPollDate = now
            return
        }

        // Same track, still playing: accumulate.
        if let lastPoll = lastPollDate {
            let delta = now.timeIntervalSince(lastPoll)
            if delta > 0 && delta < 5 { // Ignore gaps longer than 5 s (e.g. sleep/wake)
                accumulatedSeconds += delta
            }
        }
        lastPollDate = now

        // Check the threshold.
        if !logged {
            let threshold = min(30, track.duration * 0.5)
            if accumulatedSeconds >= threshold {
                logPlay(track: track)
            }
        }
    }

    /// Called when the track changes so the previous track's state is finalized.
    func finalizeIfNeeded() {
        // If we hadn't logged but accumulated significant time, log anyway on track change
        // if we're past the threshold.
        if !logged, let track = currentTrack {
            let threshold = min(30, track.duration * 0.5)
            if accumulatedSeconds >= threshold {
                logPlay(track: track)
            }
        }
        currentTrack = nil
        listenStart = nil
        accumulatedSeconds = 0
        logged = false
        lastPollDate = nil
    }

    private func logPlay(track: Track) {
        logged = true
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let play = Play(
            title: track.title,
            artist: track.artist,
            album: track.album,
            source: track.player.displayName,
            startedAt: listenStart ?? Date(),
            secondsListened: accumulatedSeconds
        )
        context.insert(play)
        do {
            try context.save()
        } catch {
            print("[Hum] Failed to save play: \(error)")
        }
    }

    /// Exports all plays to CSV data.
    func exportCSV() -> Data? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Play>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        guard let plays = try? context.fetch(descriptor) else { return nil }
        var csv = "Title,Artist,Album,Source,Started At,Seconds Listened\n"
        let formatter = ISO8601DateFormatter()
        for play in plays {
            let escaped = { (s: String) -> String in
                let clean = s.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(clean)\""
            }
            csv += "\(escaped(play.title)),\(escaped(play.artist)),\(escaped(play.album)),\(escaped(play.source)),\(formatter.string(from: play.startedAt)),\(Int(play.secondsListened))\n"
        }
        return csv.data(using: .utf8)
    }
}
