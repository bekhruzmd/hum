import Carbon.HIToolbox
import XCTest
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

    @MainActor func testTargetsOnlyExistingContainers() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        XCTAssertEqual(ScreensaverFeedWriter.targetDirectories(home: home).count, 1, "only the plain Application Support path")
        let container = home.appendingPathComponent("Library/Containers/\(ScreensaverFeedWriter.hostContainerIDs[0])/Data/Library/Application Support")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let targets = ScreensaverFeedWriter.targetDirectories(home: home)
        XCTAssertEqual(targets.count, 2)
        XCTAssertEqual(targets.first?.lastPathComponent, ScreensaverFeed.folderName)
    }
}
