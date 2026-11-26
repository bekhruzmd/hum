import XCTest
@testable import Hum

final class PlaybackParserTests: XCTestCase {
    private let sep = PlaybackParser.fieldSeparator

    func testSpotifyDurationIsConvertedFromMilliseconds() throws {
        let raw = ["playing", "Song", "Artist", "Album", "215000", "12,5", "https://i.scdn.co/image/abc"].joined(separator: sep)
        let state = try XCTUnwrap(PlaybackParser.parse(raw, player: .spotify))
        XCTAssertEqual(state.track.duration, 215, accuracy: 0.001)
        XCTAssertEqual(state.position, 12.5, accuracy: 0.001)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.track.artworkURL?.host, "i.scdn.co")
    }

    func testMusicDurationIsSecondsAndCommaDecimal() throws {
        let raw = ["paused", "Song, with comma", "Artist", "Album", "200,25", "3.0"].joined(separator: sep)
        let state = try XCTUnwrap(PlaybackParser.parse(raw, player: .appleMusic))
        XCTAssertEqual(state.track.duration, 200.25, accuracy: 0.001)
        XCTAssertEqual(state.track.title, "Song, with comma")
        XCTAssertFalse(state.isPlaying)
        XCTAssertNil(state.track.artworkURL)
    }

    func testShuffleIsOptionalAndParsedForBothPlayers() throws {
        for player in PlayerApp.allCases {
            let fields = ["playing", "Song", "Artist", "Album", "200", "3", ""]
            XCTAssertEqual(PlaybackParser.parse((fields + ["true"]).joined(separator: sep), player: player)?.isShuffling, true)
            XCTAssertEqual(PlaybackParser.parse((fields + ["false"]).joined(separator: sep), player: player)?.isShuffling, false)
            XCTAssertNil(PlaybackParser.parse((fields + [""]).joined(separator: sep), player: player)?.isShuffling)
            XCTAssertNil(PlaybackParser.parse(fields.joined(separator: sep), player: player)?.isShuffling)
        }
    }

    func testStoppedAndMalformedReturnNil() {
        XCTAssertNil(PlaybackParser.parse("STOPPED", player: .spotify))
        XCTAssertNil(PlaybackParser.parse("", player: .spotify))
        XCTAssertNil(PlaybackParser.parse("playing\(sep)only", player: .spotify))
        XCTAssertNil(PlaybackParser.parse(["playing", "", "A", "B", "1", "1"].joined(separator: sep), player: .appleMusic))
    }

    func testNonHTTPSArtworkIsDropped() throws {
        let raw = ["playing", "S", "A", "B", "1000", "0", "http://example.com/a.jpg"].joined(separator: sep)
        XCTAssertNil(try XCTUnwrap(PlaybackParser.parse(raw, player: .spotify)).track.artworkURL)
    }

    func testInterpolationAdvancesOnlyWhilePlaying() {
        let track = Track(title: "t", artist: "a", album: "b", duration: 100, artworkURL: nil, player: .spotify)
        let start = Date(timeIntervalSince1970: 1000)
        let playing = PlaybackState(track: track, position: 10, isPlaying: true, fetchedAt: start)
        XCTAssertEqual(playing.interpolatedPosition(at: start.addingTimeInterval(2.5)), 12.5, accuracy: 0.001)
        XCTAssertEqual(playing.interpolatedPosition(at: start.addingTimeInterval(500)), 100, accuracy: 0.001)
        let paused = PlaybackState(track: track, position: 10, isPlaying: false, fetchedAt: start)
        XCTAssertEqual(paused.interpolatedPosition(at: start.addingTimeInterval(5)), 10, accuracy: 0.001)
    }

    func testCacheKeysNormalize() {
        let a = Track(title: " Hello ", artist: "ADELE", album: "25", duration: 295.4, artworkURL: nil, player: .spotify)
        let b = Track(title: "hello", artist: "adele", album: "25", duration: 295.0, artworkURL: nil, player: .appleMusic)
        XCTAssertEqual(a.cacheKey, b.cacheKey)
        XCTAssertEqual(a.albumKey, b.albumKey)
    }
}

final class ClockSmoothingTests: XCTestCase {
    private let track = Track(title: "t", artist: "a", album: "b", duration: 200, artworkURL: nil, player: .spotify)

    func testSmallDriftKeepsAnchor() {
        let start = Date(timeIntervalSince1970: 0)
        let old = NowPlayingStore.Status.active(PlaybackState(track: track, position: 10, isPlaying: true, fetchedAt: start))
        let jitter = NowPlayingStore.Status.active(PlaybackState(track: track, position: 11.08, isPlaying: true, fetchedAt: start.addingTimeInterval(1)))
        XCTAssertEqual(NowPlayingStore.smoothed(current: old, incoming: jitter), old)
    }

    func testSeekReanchors() {
        let start = Date(timeIntervalSince1970: 0)
        let old = NowPlayingStore.Status.active(PlaybackState(track: track, position: 10, isPlaying: true, fetchedAt: start))
        let seek = NowPlayingStore.Status.active(PlaybackState(track: track, position: 90, isPlaying: true, fetchedAt: start.addingTimeInterval(1)))
        XCTAssertEqual(NowPlayingStore.smoothed(current: old, incoming: seek), seek)
    }

    func testPauseAndTrackChangeAlwaysApply() {
        let start = Date(timeIntervalSince1970: 0)
        let old = NowPlayingStore.Status.active(PlaybackState(track: track, position: 10, isPlaying: true, fetchedAt: start))
        let paused = NowPlayingStore.Status.active(PlaybackState(track: track, position: 11, isPlaying: false, fetchedAt: start.addingTimeInterval(1)))
        XCTAssertEqual(NowPlayingStore.smoothed(current: old, incoming: paused), paused)
        XCTAssertEqual(NowPlayingStore.smoothed(current: old, incoming: .nothingPlaying), .nothingPlaying)
    }

    func testShuffleChangesSurviveClockSmoothing() {
        let date = Date()
        let old = PlaybackState(track: track, position: 10, isPlaying: true, fetchedAt: date, isShuffling: false)
        let new = old.with(position: 10.01, isShuffling: true, fetchedAt: date)
        XCTAssertEqual(NowPlayingStore.smoothed(current: .active(old), incoming: .active(new)), .active(new))
        XCTAssertEqual(new.with(position: 50).isShuffling, true)
    }
}

@MainActor
final class PlaybackRefreshOrderingTests: XCTestCase {
    func testShuffleUpdatesImmediatelyAndReachesActiveSource() async {
        let source = ControlledPlaybackSource()
        let store = NowPlayingStore(sources: [source])
        let initial = Task { await store.refresh() }
        await source.waitForReads(1)
        await source.resolve(1, with: Self.state(title: "Track", position: 5).with(isShuffling: false))
        await initial.value
        store.toggleShuffle()
        XCTAssertEqual(store.playbackState?.isShuffling, true)
        let requested = await source.nextShuffleCommand()
        XCTAssertTrue(requested)
    }

    func testOlderPollCannotReplaceNewerResult() async {
        let source = ControlledPlaybackSource()
        let store = NowPlayingStore(sources: [source])
        let first = Task { await store.refresh() }
        await source.waitForReads(1)
        let second = Task { await store.refresh() }
        await source.waitForReads(2)
        let latest = Self.state(title: "New track", position: 30)
        await source.resolve(2, with: latest)
        await second.value
        await source.resolve(1, with: Self.state(title: "Old track", position: 5))
        await first.value
        XCTAssertEqual(store.currentTrack?.title, "New track")
    }

    func testControlInvalidatesInFlightPollAndSeekIsBounded() async {
        let source = ControlledPlaybackSource()
        let store = NowPlayingStore(sources: [source])
        let initial = Task { await store.refresh() }
        await source.waitForReads(1)
        await source.resolve(1, with: Self.state(title: "Track", position: 5))
        await initial.value
        let stale = Task { await store.refresh() }
        await source.waitForReads(2)
        store.seek(to: 500)
        await source.resolve(2, with: Self.state(title: "Track", position: 6))
        await stale.value
        XCTAssertEqual(store.playbackState?.position, 100)
        store.seek(to: -10)
        XCTAssertEqual(store.playbackState?.position, 0)
    }

    private static func state(title: String, position: TimeInterval) -> PlaybackState {
        PlaybackState(
            track: Track(title: title, artist: "Test", album: UUID().uuidString, duration: 100, artworkURL: nil, player: .spotify),
            position: position, isPlaying: true, fetchedAt: Date()
        )
    }
}

private actor ControlledPlaybackSource: PlaybackSource {
    nonisolated let id = PlayerApp.spotify
    nonisolated let name = "Test source"
    nonisolated let isRunning = true
    private var reads = 0
    private var pending: [Int: CheckedContinuation<PlaybackState?, Never>] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var shuffleCommands: [Bool] = []
    private var shuffleWaiter: CheckedContinuation<Bool, Never>?

    func setShuffle(_ enabled: Bool) async {
        if let waiter = shuffleWaiter {
            shuffleWaiter = nil
            waiter.resume(returning: enabled)
        } else { shuffleCommands.append(enabled) }
    }

    func nextShuffleCommand() async -> Bool {
        if !shuffleCommands.isEmpty { return shuffleCommands.removeFirst() }
        return await withCheckedContinuation { shuffleWaiter = $0 }
    }

    func current() async throws -> PlaybackState? {
        await withCheckedContinuation { continuation in
            reads += 1
            pending[reads] = continuation
            for (count, waiter) in waiters where reads >= count { waiter.resume() }
            waiters.removeAll { reads >= $0.0 }
        }
    }

    func waitForReads(_ count: Int) async {
        guard reads < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func resolve(_ read: Int, with state: PlaybackState) {
        pending.removeValue(forKey: read)?.resume(returning: state)
    }

    func artworkData() async -> Data? { nil }
    func playPause() async {}
    func nextTrack() async {}
    func previousTrack() async {}
    func seek(to position: TimeInterval) async {}
}
