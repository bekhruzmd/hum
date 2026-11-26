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
}
