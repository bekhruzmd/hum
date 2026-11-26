import Carbon.HIToolbox
import XCTest
import Metal
@testable import Hum

final class SoundSynthTests: XCTestCase {
    func testNeedleDropIsDeterministicBoundedAndDecays() {
        let a = SoundSynth.needleDrop()
        XCTAssertEqual(a, SoundSynth.needleDrop())
        XCTAssertEqual(a.count, Int(SoundSynth.sampleRate * 0.9))
        XCTAssertTrue(a.allSatisfy { abs($0) <= 1 })
        let head = a.prefix(4410).map { abs($0) }.max() ?? 0
        let tail = a.suffix(4410).map { abs($0) }.max() ?? 1
        XCTAssertGreaterThan(head, tail * 2, "the thump should be louder than the tail")
    }

    func testCrackleIsQuietAndNotSilent() {
        var generator = CrackleGenerator()
        let samples = (0..<44_100).map { _ in generator.next() }
        let peak = samples.map(abs).max() ?? 0
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        XCTAssertLessThan(peak, 0.6)
        XCTAssertGreaterThan(rms, 0.001)
        XCTAssertLessThan(rms, 0.1)
    }
}

final class KeyComboTests: XCTestCase {
    func testDisplayAndModifiers() {
        let combo = KeyCombo(keyCode: UInt16(kVK_ANSI_L), flags: [.control, .option])
        XCTAssertEqual(combo.displayString, "⌃⌥L")
        XCTAssertTrue(combo.hasRequiredModifier)
        XCTAssertFalse(KeyCombo(keyCode: UInt16(kVK_ANSI_L), flags: [.shift]).hasRequiredModifier)
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(cmdKey | shiftKey)).displayString, "⇧⌘Space")
    }

    func testHotKeyIDsAreUnique() {
        let ids = HotkeyAction.allCases.map(\.hotKeyID)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.contains(0))
    }
}

@MainActor
final class HotkeyStoreTests: XCTestCase {
    func testDefaultsPersistAndConflictsMove() throws {
        let suite = "hum.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = HotkeyStore(defaults: defaults)
        XCTAssertEqual(store.bindings, HotkeyAction.defaults)

        let nextCombo = try XCTUnwrap(store.bindings[.nextTrack])
        store.set(nextCombo, for: .playPause)
        XCTAssertEqual(store.bindings[.playPause], nextCombo)
        XCTAssertNil(store.bindings[.nextTrack], "a combo can only belong to one action")

        store.set(nil, for: .idleScreen)
        let reloaded = HotkeyStore(defaults: defaults)
        XCTAssertNil(reloaded.bindings[.idleScreen])
        XCTAssertNil(reloaded.bindings[.nextTrack])
        XCTAssertEqual(reloaded.bindings[.playPause], nextCombo)
    }
}

final class ScreensaverFeedTests: XCTestCase {
    func testPlayerProgressIsIndependentOfLyricOffsetAndStopsAtDuration() throws {
        var feed = ScreensaverFeed(track: SceneTrackInfo(title: "Track", artist: "Artist", album: "Album", duration: 100),
                                   lyricAnchor: 15, anchorDate: 1000, isPlaying: true,
                                   playbackAnchor: 10, isShuffling: true)
        let decoded = try JSONDecoder().decode(ScreensaverFeed.self, from: JSONEncoder().encode(feed))
        let date = Date(timeIntervalSince1970: 1002)
        XCTAssertEqual(decoded.lyricTime(at: date), 17)
        XCTAssertEqual(decoded.playbackPosition(at: date), 12)
        XCTAssertEqual(decoded.playbackPosition(at: Date(timeIntervalSince1970: 1200)), 100)
        XCTAssertEqual(decoded.isShuffling, true)
        feed.isPlaying = false
        XCTAssertEqual(feed.playbackPosition(at: date), 10)
        let legacy = Data(#"{"title":"Track","artist":"Artist","album":"Album"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SceneTrackInfo.self, from: legacy).duration)
    }

    func testRefractionShaderIsBundledInAppAndSaver() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let appLibrary = try device.makeDefaultLibrary(bundle: Bundle.main)
        XCTAssertTrue(appLibrary.functionNames.contains("humRefraction"))
        let saverURL = try XCTUnwrap(Bundle.main.url(forResource: "Hum", withExtension: "saver"))
        let saver = try XCTUnwrap(Bundle(url: saverURL))
        let saverLibrary = try device.makeDefaultLibrary(bundle: saver)
        XCTAssertTrue(saverLibrary.functionNames.contains("humRefraction"))
    }

    func testCinematicLookRoundTripAndLegacyDefault() throws {
        let old = ScreensaverFeed()
        XCTAssertEqual(old.cinematicLook, .album)
        XCTAssertEqual(old.edgeGlowIntensity, 1)
        var poster = old
        poster.look = CinematicLook.monochrome.rawValue
        poster.edgeGlow = 3
        let restored = try JSONDecoder().decode(ScreensaverFeed.self, from: JSONEncoder().encode(poster))
        XCTAssertEqual(restored.cinematicLook, .monochrome)
        XCTAssertEqual(restored.edgeGlowIntensity, 3)
    }

    func testFeedExpiresWhenAppStops() {
        let feed = ScreensaverFeed(anchorDate: 1000)
        XCTAssertTrue(feed.isFresh(at: Date(timeIntervalSince1970: 1010)))
        XCTAssertFalse(feed.isFresh(at: Date(timeIntervalSince1970: 1021)))
        XCTAssertFalse(feed.isFresh(at: Date(timeIntervalSince1970: 900)))
        XCTAssertFalse(ScreensaverFeed().isFresh(at: Date()))
    }

    @MainActor func testNewDestinationReceivesArtworkAndMissingCoverIsRepaired() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let artwork = Data([1, 2, 3])
        let feed = ScreensaverFeed(artworkFile: ScreensaverFeedWriter.artworkFileName(for: artwork))
        let json = try JSONEncoder().encode(feed)
        for name in ["original", "new-container"] {
            let directory = root.appendingPathComponent(name)
            try ScreensaverFeedWriter.publish(feed: feed, json: json, artwork: artwork, to: directory)
            let cover = directory.appendingPathComponent(try XCTUnwrap(feed.artworkFile))
            XCTAssertEqual(try Data(contentsOf: cover), artwork)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(ScreensaverFeed.fileName)), json)
            try FileManager.default.removeItem(at: cover)
            try ScreensaverFeedWriter.publish(feed: feed, json: json, artwork: artwork, to: directory)
            XCTAssertEqual(try Data(contentsOf: cover), artwork)
        }
    }

    @MainActor func testFailedInstallPreservesExistingBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = root.appendingPathComponent("Hum.saver")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let marker = destination.appendingPathComponent("version")
        try Data("old".utf8).write(to: marker)
        XCTAssertThrowsError(try ScreensaverInstaller.replaceBundle(from: root.appendingPathComponent("missing"), at: destination))
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "old")
        let source = root.appendingPathComponent("new.saver")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: source.appendingPathComponent("version"))
        try ScreensaverInstaller.replaceBundle(from: source, at: destination)
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "new")
    }

    func testRoundTripAndTiming() throws {
        let lines = WordTimingEstimator.timedLines(from: LRCParser.parse("[00:01.00]hello there"), trackDuration: 100)
        let feed = ScreensaverFeed(
            track: SceneTrackInfo(title: "t", artist: "a", album: "b"),
            lyricAnchor: 10, anchorDate: 1000, isPlaying: true,
            lines: lines, effect: "constellation", artworkFile: "artwork-1.img"
        )
        let decoded = try JSONDecoder().decode(ScreensaverFeed.self, from: JSONEncoder().encode(feed))
        XCTAssertEqual(decoded, feed)
        XCTAssertEqual(decoded.lyricTime(at: Date(timeIntervalSince1970: 1002.5)), 12.5, accuracy: 1e-9)
        var paused = decoded
        paused.isPlaying = false
        XCTAssertEqual(paused.lyricTime(at: Date(timeIntervalSince1970: 5000)), 10)
        XCTAssertEqual(decoded.effectKind, .constellation)
    }

    @MainActor func testWriterAndReaderUseSameRealHomeOutsideHostContainer() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let container = home.appendingPathComponent("Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Application Support")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let expected = home.appendingPathComponent("Library/Application Support/Hum", isDirectory: true)
        XCTAssertEqual(ScreensaverFeedWriter.targetDirectories(home: home), [expected])
        XCTAssertEqual(ScreensaverFeed.directory(home: home), expected)
        XCTAssertEqual(ScreensaverFeedWriter.targetDirectories(), [ScreensaverFeed.directory()])
        XCTAssertFalse(ScreensaverFeed.realHomeDirectory.path.contains("Library/Containers"))
    }

    func testDisabledFeedIsFreshButContainsNoSong() throws {
        let now = Date()
        let feed = ScreensaverFeed(sharingEnabled: false, anchorDate: now.timeIntervalSince1970)
        let decoded = try JSONDecoder().decode(ScreensaverFeed.self, from: JSONEncoder().encode(feed))
        XCTAssertTrue(decoded.isFresh(at: now))
        XCTAssertEqual(decoded.sharingEnabled, false)
        XCTAssertNil(decoded.track)
        XCTAssertNil(decoded.artworkFile)
    }
}

final class ConstellationLayoutTests: XCTestCase {
    func testCatalogHasValidCoordinates() {
        for def in ConstellationLayout.catalog {
            XCTAssertFalse(def.name.isEmpty)
            XCTAssertGreaterThanOrEqual(def.anchors.count, 4)
            for anchor in def.anchors {
                XCTAssertGreaterThanOrEqual(anchor.x, 0)
                XCTAssertLessThanOrEqual(anchor.x, 1)
                XCTAssertGreaterThanOrEqual(anchor.y, 0)
                XCTAssertLessThanOrEqual(anchor.y, 1)
            }
        }
        XCTAssertGreaterThanOrEqual(ConstellationLayout.freestyleNames.count, 10)
    }

    func testPositionsAdvanceForwardAcrossDisplay() {
        // Test multiple lines to hit both authentic and freestyle procedural constellations
        for lineID in 1...10 {
            let words = (1...6).map { TimedWord(text: "word\($0)", start: Double($0), end: Double($0) + 0.8) }
            let line = TimedLine(id: lineID, text: "word1 word2 word3 word4 word5 word6", start: 1.0, end: 6.0, words: words, isEstimated: false)
            let rect = CGRect(x: 0, y: 0, width: 800, height: 400)
            let layout = ConstellationLayout(line: line, in: rect)
            
            XCTAssertEqual(layout.stars.count, 6)
            XCTAssertFalse(layout.constellationName.isEmpty)
            // Check that stars advance strictly forward in X
            for i in 1..<layout.stars.count {
                XCTAssertGreaterThanOrEqual(layout.stars[i].basePoint.x, layout.stars[i-1].basePoint.x,
                                            "Star \(i) should advance forward or equal in X compared to star \(i-1) in line \(lineID)")
            }
            
            // Check that stars are not cramped into an 80px cluster
            let xs = layout.stars.map { $0.basePoint.x }
            let spanX = (xs.max() ?? 0) - (xs.min() ?? 0)
            XCTAssertGreaterThan(spanX, 300, "Constellation should span across most of the display width in line \(lineID)")
        }
    }

    func testSingleWordAndEmptyWordLines() {
        let singleWord = TimedLine(id: 2, text: "Solo", start: 1.0, end: 2.0, words: [TimedWord(text: "Solo", start: 1.0, end: 1.5)], isEstimated: false)
        let rect = CGRect(x: 0, y: 0, width: 500, height: 300)
        let singleLayout = ConstellationLayout(line: singleWord, in: rect)
        XCTAssertEqual(singleLayout.stars.count, 1)
        XCTAssertEqual(singleLayout.stars[0].basePoint.x, rect.midX)
        XCTAssertEqual(singleLayout.stars[0].basePoint.y, rect.midY)

        let emptyLine = TimedLine(id: 3, text: "", start: 1.0, end: 2.0, words: [], isEstimated: false)
        let emptyLayout = ConstellationLayout(line: emptyLine, in: rect)
        XCTAssertEqual(emptyLayout.stars.count, 1)
    }
}
