import AppKit
import Observation
import SwiftUI

/// Creates and owns Hum's AppKit windows (lyrics, settings, and later surfaces).
@Observable
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private(set) var isLyricsVisible = false

    @ObservationIgnored private unowned let environment: AppEnvironment
    @ObservationIgnored private var lyricsWindow: NSWindow?
    @ObservationIgnored private var settingsWindow: NSWindow?

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()
    }

    // MARK: Lyrics window

    func showLyrics() {
        let window = lyricsWindow ?? makeLyricsWindow()
        lyricsWindow = window
        window.orderFrontRegardless()
        isLyricsVisible = true
    }

    func hideLyrics() {
        lyricsWindow?.orderOut(nil)
        isLyricsVisible = false
    }

    func toggleLyrics() {
        isLyricsVisible ? hideLyrics() : showLyrics()
    }

    private func makeLyricsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Hum"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self

        let hosting = NSHostingController(rootView: LyricsWindowView(environment: environment))
        hosting.sizingOptions = [.minSize, .maxSize]
        window.contentViewController = hosting

        window.setFrameAutosaveName("HumLyricsWindow")
        if !window.setFrameUsingName("HumLyricsWindow") {
            window.center()
        }

        observeContinuously(self) { manager in
            manager.applyLyricsWindowSettings()
        }
        return window
    }

    private func applyLyricsWindowSettings() {
        let settings = environment.settings
        let floatOnTop = settings.floatOnTop
        let opacity = settings.windowOpacity
        guard let window = lyricsWindow else { return }
        window.level = floatOnTop ? .floating : .normal
        window.alphaValue = min(max(opacity, 0.35), 1.0)
    }

    // MARK: Settings window

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(environment: environment))
        // Fixed size: letting animated content (the effect preview) drive the window size made
        // AppKit re-layout every frame until it threw an exception and the app quit.
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = "Hum Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(SettingsView.size)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === lyricsWindow {
            isLyricsVisible = false
        }
    }
}
