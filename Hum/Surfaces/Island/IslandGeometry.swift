import CoreGraphics

/// Where the island sits on a screen, in AppKit screen coordinates (origin bottom-left).
///
/// On a notched display the collapsed island wraps the notch with a small "ear" on each side.
/// Elsewhere it is a pill centered just under the menu bar.
struct IslandGeometry: Equatable {
    static let earWidth: CGFloat = 40
    static let expandedSize = CGSize(width: 470, height: 184)
    static let pillSize = CGSize(width: 210, height: 30)
    static let pillGap: CGFloat = 6

    let screenFrame: CGRect
    let hasNotch: Bool
    let notchWidth: CGFloat
    /// Height of the notch (safe area top inset); 0 without a notch.
    let notchHeight: CGFloat
    let menuBarHeight: CGFloat

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`.
    ///   - leftArea/rightArea: `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
    static func make(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        leftArea: CGRect?,
        rightArea: CGRect?,
        menuBarHeight: CGFloat
    ) -> IslandGeometry {
        if safeAreaTop > 0, let leftArea, let rightArea {
            let width = max(0, screenFrame.width - leftArea.width - rightArea.width)
            return IslandGeometry(
                screenFrame: screenFrame, hasNotch: width > 0, notchWidth: width,
                notchHeight: safeAreaTop, menuBarHeight: menuBarHeight
            )
        }
        return IslandGeometry(
            screenFrame: screenFrame, hasNotch: false, notchWidth: 0,
            notchHeight: 0, menuBarHeight: menuBarHeight
        )
    }

    var collapsedSize: CGSize {
        hasNotch
            ? CGSize(width: notchWidth + 2 * Self.earWidth, height: notchHeight)
            : Self.pillSize
    }

    /// The y of the island's top edge.
    private var top: CGFloat {
        hasNotch ? screenFrame.maxY : screenFrame.maxY - menuBarHeight - Self.pillGap
    }

    var collapsedFrame: CGRect { frame(for: collapsedSize) }

    var expandedFrame: CGRect {
        let height = Self.expandedSize.height + (hasNotch ? notchHeight : 0)
        return frame(for: CGSize(width: Self.expandedSize.width, height: height))
    }

    private func frame(for size: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height)
    }
}
