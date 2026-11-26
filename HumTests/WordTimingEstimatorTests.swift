import XCTest
@testable import Hum

final class WordTimingEstimatorTests: XCTestCase {
    func testWeightsByCharacterCount() {
        let words = WordTimingEstimator.estimate(text: "a bbb", start: 0, end: 4)
        XCTAssertEqual(words.map(\.text), ["a", "bbb"])
        XCTAssertEqual(words[0].start, 0, accuracy: 1e-9)
        XCTAssertEqual(words[0].end, 1, accuracy: 1e-9)
        XCTAssertEqual(words[1].start, 1, accuracy: 1e-9)
        XCTAssertEqual(words[1].end, 4, accuracy: 1e-9)
    }

    func testPauseAfterPunctuation() {
        // "ab," = 2 letters + 3 pause units, "cd" = 2 letters → total 7 units over 7 s.
        let words = WordTimingEstimator.estimate(text: "ab, cd", start: 0, end: 7)
        XCTAssertEqual(words[0].end, 2, accuracy: 1e-9)
        XCTAssertEqual(words[1].start, 5, accuracy: 1e-9)
        XCTAssertEqual(words[1].end, 7, accuracy: 1e-9)
    }

    func testWordsAreMonotonicAndInsideLine() {
        let words = WordTimingEstimator.estimate(text: "One, two! Three… four five?", start: 10, end: 14)
        XCTAssertEqual(words.first?.start ?? 0, 10, accuracy: 1e-9)
        for (a, b) in zip(words, words.dropFirst()) {
            XCTAssertLessThanOrEqual(a.end, b.start + 1e-9)
        }
        XCTAssertLessThanOrEqual(words.last?.end ?? 99, 14 + 1e-9)
    }

    func testLongGapIsCapped() {
        let line = LyricLine(id: 0, time: 0, text: "short")
        let timed = WordTimingEstimator.timedLine(for: line, nextStart: 60)
        XCTAssertLessThan(timed.end, 5)
        XCTAssertTrue(timed.isEstimated)
    }

    func testEnhancedTimesAreUsed() {
        let line = LyricLine(
            id: 0, time: 1, text: "hi there",
            words: [LyricWord(time: 1, text: "hi "), LyricWord(time: 1.6, text: "there")],
            endTime: 2.5
        )
        let timed = WordTimingEstimator.timedLine(for: line, nextStart: 10)
        XCTAssertFalse(timed.isEstimated)
        XCTAssertEqual(timed.words.map(\.text), ["hi", "there"])
        XCTAssertEqual(timed.words[0].end, 1.6, accuracy: 1e-9)
        XCTAssertEqual(timed.words[1].end, 2.5, accuracy: 1e-9)
        XCTAssertEqual(timed.end, 2.5, accuracy: 1e-9)
    }

    func testProgressAndCurrentWord() {
        let timed = WordTimingEstimator.timedLine(for: LyricLine(id: 0, time: 0, text: "aa bb"), nextStart: 2)
        XCTAssertNil(timed.currentWordIndex(at: -1))
        XCTAssertEqual(timed.currentWordIndex(at: 0.1), 0)
        XCTAssertEqual(timed.currentWordIndex(at: timed.words[1].start + 0.01), 1)
        XCTAssertEqual(timed.fill(ofWord: 0, at: timed.words[0].end / 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(timed.progress(at: 5), 1)
    }

    func testEmptyLine() {
        let timed = WordTimingEstimator.timedLine(for: LyricLine(id: 0, time: 3, text: ""), nextStart: 8)
        XCTAssertTrue(timed.words.isEmpty)
        XCTAssertEqual(timed.displayText, "♪")
    }

    func testActiveIndexOnTimedLines() {
        let lines = WordTimingEstimator.timedLines(
            from: [LyricLine(id: 0, time: 1, text: "a"), LyricLine(id: 1, time: 5, text: "b")],
            trackDuration: 10
        )
        XCTAssertNil(lines.activeIndex(at: 0.5))
        XCTAssertEqual(lines.activeIndex(at: 4.9), 0)
        XCTAssertEqual(lines.activeIndex(at: 9), 1)
    }
}

@MainActor
final class OffsetStoreTests: XCTestCase {
    func testAdjustRoundsAndPersists() throws {
        let suite = "hum.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let track = Track(title: "t", artist: "a", album: "b", duration: 100, artworkURL: nil, player: .spotify)

        let store = OffsetStore(defaults: defaults)
        for _ in 0..<3 { store.adjust(track, by: OffsetStore.step) }
        XCTAssertEqual(store.offset(for: track), 0.3, accuracy: 1e-9)
        XCTAssertEqual(OffsetStore(defaults: defaults).offset(for: track), 0.3, accuracy: 1e-9)

        store.reset(track)
        XCTAssertEqual(store.offset(for: track), 0)
        XCTAssertEqual(store.offset(for: nil), 0)
    }
}
