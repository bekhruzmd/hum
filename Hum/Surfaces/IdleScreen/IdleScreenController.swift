import AppKit
import SwiftUI

/// Shows the idle screen after N idle minutes (while music plays) or on demand.
///
/// Windows sit at pop-up-menu level: above apps, the Dock and the menu bar, but below the
/// screensaver and the system lock screen, which always cover it. Any input dismisses it.
@MainActor
final class IdleScreenController {
    private unowned let environment: AppEnvironment
    private var windows: [NSWindow] = []
    private var monitors: [Any] = []
    private var checkTask: Task<Void, Never>?
    private var shownAt: Date = .distantPast
    private var mouseTravel: CGFloat = 0

    private(set) var isShowing = false

    static let level = NSWindow.Level.popUpMenu
    static let checkInterval: Duration = .seconds(15)
    /// Input in the first moments after showing is ignored so the trigger itself doesn't dismiss.
    static let graceInterval: TimeInterval = 0.8

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        observeContinuously(self) { controller in
            controller.restartIdleCheck(minutes: controller.environment.settings.idleMinutes)
        }
    }

    // MARK: Idle detection

    private func restartIdleCheck(minutes: Int) {
        checkTask?.cancel()
        guard minutes > 0 else { return }
        checkTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.checkInterval)
                self?.checkIdle(minutes: minutes)
            }
        }
    }

    private func checkIdle(minutes: Int) {
        guard !isShowing, environment.nowPlaying.isPlaying, environment.renderGate.canAnimate else { return }
        if Self.secondsSinceLastInput() >= TimeInterval(minutes * 60) {
            show()
        }
    }

    static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType (~0): imported C enums accept unknown raw values.
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    // MARK: Show / dismiss

    func show() {
        guard !isShowing else { return }
        isShowing = true
        shownAt = Date()
        mouseTravel = 0
        for screen in NSScreen.screens {
            windows.append(makeWindow(for: screen))
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSCursor.setHiddenUntilMouseMoves(true)
        installMonitors()
    }

    func dismiss() {
        guard isShowing else { return }
        isShowing = false
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = IdleWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.backgroundColor = .black
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: IdleScreenRoot(environment: environment))
        window.setFrame(screen.frame, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            window.animator().alphaValue = 1
        }
        return window
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .mouseMoved
        ]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handleInput(event) ?? false }
            return consumed ? nil : event
        }) {
            monitors.append(local)
        }
        // Global mouse events still arrive if another app grabs focus. (Global key events
        // would need Accessibility permission, which Hum doesn't ask for.)
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleInput(event) }
        }) {
            monitors.append(global)
        }
    }

    /// Returns true when the event dismissed the idle screen (and should be swallowed).
    private func handleInput(_ event: NSEvent) -> Bool {
        guard isShowing, Date().timeIntervalSince(shownAt) > Self.graceInterval else { return isShowing }
        if event.type == .mouseMoved {
            mouseTravel += abs(event.deltaX) + abs(event.deltaY)
            guard mouseTravel > 6 else { return true }
        }
        dismiss()
        return true
    }
}

private final class IdleWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Picks the idle screen style.
private struct IdleScreenRoot: View {
    let environment: AppEnvironment

    var body: some View {
        switch environment.settings.idleStyle {
        case .cinematic:
            CinematicScene(data: environment.cinematicData(), animate: environment.renderGate.canAnimateHeavy)
        case .classic:
            IdleScreenView(environment: environment)
        }
    }
}
