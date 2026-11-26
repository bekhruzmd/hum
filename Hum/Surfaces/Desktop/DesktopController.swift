import AppKit
import SwiftUI

/// One borderless window per display at desktop level: above the wallpaper, below Finder's
/// icons, click-through, on every Space. Rebuilt when displays change.
@MainActor
final class DesktopController {
    private unowned let environment: AppEnvironment
    private var windows: [NSWindow] = []
    private var occlusionTokens: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var builtForMode: DesktopMode = .off

    /// Just above the wallpaper; Finder's icons live at the higher desktop-icon level.
    static let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        observeContinuously(self) { controller in
            let mode = controller.environment.settings.desktopMode
            if mode != controller.builtForMode {
                controller.builtForMode = mode
                controller.rebuild()
            }
        }
    }

    private func rebuild() {
        tearDown()
        guard environment.settings.desktopMode != .off else { return }
        for screen in NSScreen.screens {
            windows.append(makeWindow(for: screen))
        }
    }

    private func tearDown() {
        occlusionTokens.forEach(NotificationCenter.default.removeObserver)
        occlusionTokens.removeAll()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        let model = DesktopWindowModel()
        window.contentView = NSHostingView(rootView: DesktopView(environment: environment, model: model))
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()

        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                model.isVisible = window?.occlusionState.contains(.visible) ?? false
            }
        }
        occlusionTokens.append(token)
        return window
    }
}
