import AppKit

/// A borderless, non-activating panel that floats above the menu bar on every Space.
final class IslandPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    /// Key status lets the scrubber drag and buttons respond without activating Hum.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setShowsOverFullScreenApps(_ shows: Bool) {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if shows { behavior.insert(.fullScreenAuxiliary) }
        collectionBehavior = behavior
    }
}
