import AppKit
import SwiftUI
import XCTest
@testable import Hum

/// Regression: opening Settings used to quit the app (the animated effect preview drove the
/// window size, and AppKit threw after re-laying out every frame).
@MainActor
final class SettingsWindowTests: XCTestCase {
    func testMiniPlayerUsesBoundedWindowSizeAndStopsWhenClosed() {
        let environment = AppEnvironment()
        environment.windows.showMiniPlayer()
        let window = NSApp.windows.first { $0.title == "Hum · Mini Player" }
        XCTAssertEqual(window?.frame.size, NSSize(width: 352, height: 178))
        environment.windows.isPlayerArtworkExpanded = true
        environment.windows.resizeMiniPlayer()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(window?.frame.size, NSSize(width: 352, height: 498))
        window?.close()
        XCTAssertFalse(environment.windows.isMiniPlayerVisible)
        XCTAssertFalse(environment.windows.canRenderMiniPlayer)
    }

    func testSettingsWindowSurvivesEveryEffectPreview() {
        let environment = AppEnvironment()
        let original = environment.settings.lyricEffect
        defer { environment.settings.lyricEffect = original }

        environment.windows.showSettings()
        let window = NSApp.windows.first { $0.title == "Settings" }
        XCTAssertNotNil(window)
        for effect in LyricEffectKind.allCases {
            environment.settings.lyricEffect = effect
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        }
        XCTAssertEqual(window?.contentView?.frame.size, SettingsView.size)
        window?.close()
    }
}

/// Every Settings page, including the animated island and glow previews, must lay out at the
/// fixed window size without resizing it (the class of bug that once quit the app).
@MainActor
final class SettingsPagesTests: XCTestCase {
    func testEveryPageKeepsTheWindowSize() {
        let environment = AppEnvironment()
        for page in SettingsPage.allCases {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: SettingsView.size),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            // Swift owns the window; AppKit must not also release it on close.
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: SettingsView(environment: environment, initialPage: page))
            hosting.sizingOptions = []
            window.contentView = hosting
            window.orderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            XCTAssertEqual(window.contentView?.frame.size, SettingsView.size, "\(page.title) resized the window")
            window.close()
        }
    }

    func testFeatureListAndSearchKeywordsCoverEveryPage() {
        XCTAssertEqual(Set(SettingsPage.features + [.nowPlaying, .general]), Set(SettingsPage.allCases))
        for page in SettingsPage.allCases {
            XCTAssertFalse(page.keywords.isEmpty)
        }
    }
}

final class GlowAndIslandSettingsTests: XCTestCase {
    func testGlowAppearanceRoundTripsAndPicksColor() throws {
        var appearance = GlowAppearance()
        appearance.colorMode = .custom
        appearance.customColor = RGB(r: 0.1, g: 0.2, b: 0.3)
        appearance.style = .pulse
        let decoded = try JSONDecoder().decode(GlowAppearance.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(decoded, appearance)
        XCTAssertEqual(decoded.color(for: .fallback), RGB(r: 0.1, g: 0.2, b: 0.3))
        XCTAssertEqual(GlowAppearance().color(for: .fallback), AlbumPalette.fallback.dominantGlowColor)
    }

    func testBeatPulseFlaresOnWordsAndRestsWhenPaused() {
        let lines = WordTimingEstimator.timedLines(from: LRCParser.parse("[00:10.00]one two three four"), trackDuration: 60)
        let first = lines[0].words[0].start
        XCTAssertGreaterThan(BeatPulse.value(lines: lines, time: first + 0.01, isPlaying: true), 0.9)
        XCTAssertEqual(BeatPulse.value(lines: lines, time: first + 0.01, isPlaying: false), 0)
        let withoutLyrics = BeatPulse.value(lines: [], time: 3, isPlaying: true)
        XCTAssertGreaterThanOrEqual(withoutLyrics, 0)
        XCTAssertLessThanOrEqual(withoutLyrics, 0.5)
    }

    func testIslandSizesGrowAndGeometryAddsNotch() {
        XCTAssertLessThan(IslandSize.compact.expanded.height, IslandSize.regular.expanded.height)
        XCTAssertLessThan(IslandSize.regular.expanded.height, IslandSize.large.expanded.height)
        let geometry = IslandGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            leftArea: CGRect(x: 0, y: 950, width: 662, height: 32), rightArea: CGRect(x: 850, y: 950, width: 662, height: 32),
            menuBarHeight: 37)
        let frame = geometry.expandedFrame(content: IslandSize.large.expanded)
        XCTAssertEqual(frame.height, IslandSize.large.expanded.height + 32)
        XCTAssertEqual(frame.maxY, 982)
        XCTAssertEqual(frame.midX, 756)
    }
}
