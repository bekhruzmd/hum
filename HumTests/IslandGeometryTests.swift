import XCTest
@testable import Hum

final class IslandGeometryTests: XCTestCase {
    func testNotchedScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = IslandGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            leftArea: CGRect(x: 0, y: 950, width: 662, height: 32),
            rightArea: CGRect(x: 850, y: 950, width: 662, height: 32),
            menuBarHeight: 37
        )
        XCTAssertTrue(geometry.hasNotch)
        XCTAssertEqual(geometry.notchWidth, 188)
        XCTAssertEqual(geometry.collapsedFrame.width, 188 + 2 * IslandGeometry.earWidth)
        XCTAssertEqual(geometry.collapsedFrame.maxY, screen.maxY)
        XCTAssertEqual(geometry.collapsedFrame.midX, screen.midX)
        XCTAssertEqual(geometry.expandedFrame.maxY, screen.maxY)
        XCTAssertEqual(geometry.expandedFrame.height, IslandGeometry.expandedSize.height + 32)
    }

    func testNoNotchIsPillUnderMenuBar() {
        let screen = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let geometry = IslandGeometry.make(screenFrame: screen, safeAreaTop: 0, leftArea: nil, rightArea: nil, menuBarHeight: 25)
        XCTAssertFalse(geometry.hasNotch)
        XCTAssertEqual(geometry.collapsedFrame.size, IslandGeometry.pillSize)
        XCTAssertEqual(geometry.collapsedFrame.maxY, screen.maxY - 25 - IslandGeometry.pillGap)
        XCTAssertEqual(geometry.collapsedFrame.midX, screen.midX)
        XCTAssertEqual(geometry.expandedFrame.maxY, geometry.collapsedFrame.maxY)
    }
}
