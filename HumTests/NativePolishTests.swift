import Carbon.HIToolbox
import SwiftUI
import XCTest
@testable import Hum

final class LyricsImporterTests: XCTestCase {
    func testTimedTextBecomesSyncedAndPlainStaysPlain() {
        XCTAssertEqual(LyricsImporter.content(from: "[00:01.00]hello\n[00:02.00]there").map(isSynced), true)
        XCTAssertEqual(LyricsImporter.content(from: "just words\nno times"), .plain("just words\nno times"))
        XCTAssertNil(LyricsImporter.content(from: "   \n "))
    }

    func testOnlyLyricsFilesAreAccepted() throws {
        XCTAssertTrue(LyricsImporter.canImport(URL(fileURLWithPath: "/tmp/song.LRC")))
        XCTAssertTrue(LyricsImporter.canImport(URL(fileURLWithPath: "/tmp/song.txt")))
        XCTAssertFalse(LyricsImporter.canImport(URL(fileURLWithPath: "/tmp/song.mp3")))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).lrc")
        defer { try? FileManager.default.removeItem(at: url) }
        try "[00:03.50]from a file".write(to: url, atomically: true, encoding: .utf8)
        guard case .synced(let lines) = LyricsImporter.content(from: url) else { return XCTFail("expected synced lyrics") }
        XCTAssertEqual(lines.first?.text, "from a file")
    }

    private func isSynced(_ content: LyricsContent) -> Bool {
        if case .synced = content { return true }
        return false
    }
}

final class ShortcutPresentationTests: XCTestCase {
    func testKeyEquivalentsForMenus() {
        let space = KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey))
        XCTAssertEqual(space.keyEquivalent, .space)
        XCTAssertEqual(space.eventModifiers, [.control, .option])
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(cmdKey)).keyEquivalent, KeyEquivalent("l"))
        XCTAssertNil(KeyCombo(keyCode: UInt32(kVK_F5), carbonModifiers: UInt32(cmdKey)).keyEquivalent, "menus can't show F-keys")
    }

    func testKeyCapsSplitModifiersFromKey() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(controlKey | optionKey))
        XCTAssertEqual(KeyCaps.parts(of: combo), ["⌃", "⌥", "L"])
        let space = KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(KeyCaps.parts(of: space), ["⇧", "⌘", "Space"])
    }

    @MainActor func testPerformingAShortcutIsRecordedForOnboarding() throws {
        let suite = "hum.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HotkeyStore(defaults: defaults)
        XCTAssertNil(store.lastTriggered)
        store.noteTriggered(.showLyrics)
        XCTAssertEqual(store.lastTriggered, .showLyrics)
        XCTAssertEqual(store.triggerCount, 1)
    }
}
