import AppKit
import XCTest
@testable import Hum

/// Regression: opening Settings used to quit the app (the animated effect preview drove the
/// window size, and AppKit threw after re-laying out every frame).
@MainActor
final class SettingsWindowTests: XCTestCase {
    func testSettingsWindowSurvivesEveryEffectPreview() {
        let environment = AppEnvironment()
        let original = environment.settings.lyricEffect
        defer { environment.settings.lyricEffect = original }

        environment.windows.showSettings()
        let window = NSApp.windows.first { $0.title == "Hum Settings" }
        XCTAssertNotNil(window)
        for effect in LyricEffectKind.allCases {
            environment.settings.lyricEffect = effect
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        }
        XCTAssertEqual(window?.contentLayoutRect.size, SettingsView.size)
        window?.close()
    }
}
