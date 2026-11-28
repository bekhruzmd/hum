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

final class IslandPanelGeometryTests: XCTestCase {
    private let geometry = IslandGeometry.make(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
        leftArea: CGRect(x: 0, y: 950, width: 662, height: 32), rightArea: CGRect(x: 850, y: 950, width: 662, height: 32),
        menuBarHeight: 37)

    func testPanelHoldsEveryOpenSizeWithoutResizing() {
        let panel = geometry.panelFrame(maxContent: IslandSize.large.expanded)
        XCTAssertEqual(panel.maxY, 982, "pinned to the top of the screen")
        XCTAssertEqual(panel.midX, 756, accuracy: 0.001)
        for size in IslandSize.allCases {
            XCTAssertTrue(panel.contains(geometry.expandedFrame(content: size.expanded)), "\(size) must fit inside the panel")
        }
        XCTAssertTrue(panel.contains(geometry.collapsedFrame))
    }

    func testHitAreaFollowsOpenStateAndReachesTheTopEdge() {
        let content = IslandSize.regular.expanded
        let closed = geometry.hitRect(open: false, content: content)
        let open = geometry.hitRect(open: true, content: content)
        XCTAssertEqual(closed.maxY, 982)
        XCTAssertEqual(open.maxY, 982)
        XCTAssertTrue(open.contains(closed))
        // A point well below the closed island but inside the open one.
        let below = CGPoint(x: 756, y: 982 - 32 - 80)
        XCTAssertFalse(closed.contains(below))
        XCTAssertTrue(open.contains(below))
        // The menu bar far to the side is never captured.
        XCTAssertFalse(open.contains(CGPoint(x: 100, y: 970)))
    }
}
