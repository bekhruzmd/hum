import XCTest
@testable import Hum

final class LyricsCacheTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testPersistsAcrossInstances() async {
        let content = LyricsContent.synced([LyricLine(id: 0, time: 1, text: "hi", words: [LyricWord(time: 1, text: "hi")])])
        await LyricsCache(directory: directory).store(content, for: "a|b|100")
        let reloaded = await LyricsCache(directory: directory).content(for: "a|b|100")
        XCTAssertEqual(reloaded, content)
    }

    func testNotFoundExpires() async {
        let clock = Clock()
        let cache = LyricsCache(directory: directory, now: { clock.now })
        await cache.store(.notFound, for: "k")
        let fresh = await cache.content(for: "k")
        XCTAssertEqual(fresh, .notFound)
        clock.now = clock.now.addingTimeInterval(LyricsCache.notFoundTTL + 1)
        let expired = await cache.content(for: "k")
        XCTAssertNil(expired)
    }

    func testFoundDoesNotExpire() async {
        let clock = Clock()
        let cache = LyricsCache(directory: directory, now: { clock.now })
        await cache.store(.plain("words"), for: "k")
        clock.now = clock.now.addingTimeInterval(LyricsCache.notFoundTTL * 30)
        let value = await cache.content(for: "k")
        XCTAssertEqual(value, .plain("words"))
    }

    func testMissAndRemove() async {
        let cache = LyricsCache(directory: directory)
        let miss = await cache.content(for: "nope")
        XCTAssertNil(miss)
        await cache.store(.instrumental, for: "x")
        await cache.remove("x")
        let removed = await cache.content(for: "x")
        XCTAssertNil(removed)
    }
}

private final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_000_000)
}
