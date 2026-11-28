import AppKit
import Observation
import SwiftUI

/// Creates and owns Hum's AppKit windows (lyrics, settings, and later surfaces).
@Observable
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private(set) var canRenderCinematicPreview = false
    private(set) var canRenderMiniPlayer = false
    private(set) var isMiniPlayerVisible = false
    var isPlayerArtworkExpanded = false
    private(set) var isLyricsVisible = false
    private(set) var isLyricsOccluded = false
    var canRenderLyrics: Bool { isLyricsVisible && !isLyricsOccluded }

    @ObservationIgnored private unowned let environment: AppEnvironment
    @ObservationIgnored private var lyricsWindow: NSWindow?
    @ObservationIgnored private var settingsWindow: NSWindow?
    @ObservationIgnored private var cinematicPreviewWindow: NSWindow?
    @ObservationIgnored private var miniPlayerWindow: NSWindow?

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
        isLyricsOccluded = !window.occlusionState.contains(.visible)
        applyLyricsWindowSettings()
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

    // MARK: Onboarding

    @ObservationIgnored private var onboardingWindow: NSWindow?

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: OnboardingView.size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Hum"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hosting = NSHostingView(rootView: OnboardingView(environment: environment) { [weak self] in
                self?.onboardingWindow?.performClose(nil)
            })
            hosting.sizingOptions = []
            window.contentView = hosting
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func closeSettings() {
        settingsWindow?.performClose(nil)
    }

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsView.size),
            // The sidebar runs under the transparent title bar, like System Settings.
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // A bare hosting view with no sizing options: animated previews must never drive the
        // window size (that once made AppKit re-layout every frame until the app quit), and a
        // hosting controller would add the title bar's height on top of the page.
        let hosting = NSHostingView(rootView: SettingsView(environment: environment))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func showCinematicPreview() {
        if let window = cinematicPreviewWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: CinematicPreview(environment: environment))
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = "Hum · Live Preview"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 960, height: 600))
        window.minSize = NSSize(width: 480, height: 320)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        cinematicPreviewWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        canRenderCinematicPreview = window.occlusionState.contains(.visible)
    }

    func toggleMiniPlayer() {
        if isMiniPlayerVisible { miniPlayerWindow?.close() } else { showMiniPlayer() }
    }

    func showMiniPlayer() {
        let window = miniPlayerWindow ?? makeMiniPlayer()
        miniPlayerWindow = window
        isMiniPlayerVisible = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        canRenderMiniPlayer = window.occlusionState.contains(.visible)
    }

    private func makeMiniPlayer() -> NSWindow {
        isPlayerArtworkExpanded = false
        let window = MusicPlayerPanel(contentRect: NSRect(x: 0, y: 0, width: MusicBar.width + 32,
                                                          height: MusicBar.cardHeight + 32),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Hum · Mini Player"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.delegate = self
        let hosting = NSHostingController(rootView: MiniPlayerContent(environment: environment))
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: MusicBar.width + 32, height: MusicBar.cardHeight + 32))
        window.center()
        return window
    }

    func resizeMiniPlayer() {
        guard let window = miniPlayerWindow else { return }
        var frame = window.frame
        frame.size.height = (isPlayerArtworkExpanded ? MusicBar.expandedHeight : MusicBar.cardHeight) + 32
        if let screen = window.screen, frame.maxY > screen.visibleFrame.maxY {
            frame.origin.y = screen.visibleFrame.maxY - frame.height
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            window.animator().setFrame(frame, display: true)
        }
    }

    // MARK: NSWindowDelegate

    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === lyricsWindow { isLyricsOccluded = !window.occlusionState.contains(.visible) }
        if window === cinematicPreviewWindow { canRenderCinematicPreview = window.occlusionState.contains(.visible) }
        if window === miniPlayerWindow { canRenderMiniPlayer = window.occlusionState.contains(.visible) }
    }

    func windowWillClose(_ notification: Notification) {
        let window = notification.object as? NSWindow
        if window === lyricsWindow {
            isLyricsVisible = false
        } else if window === cinematicPreviewWindow {
            canRenderCinematicPreview = false
            cinematicPreviewWindow?.contentViewController = nil
            cinematicPreviewWindow = nil
        } else if window === miniPlayerWindow {
            canRenderMiniPlayer = false
            isMiniPlayerVisible = false
            miniPlayerWindow?.contentViewController = nil
            miniPlayerWindow = nil
        } else if window === onboardingWindow {
            environment.settings.hasCompletedOnboarding = true
            onboardingWindow?.contentView = nil
            onboardingWindow = nil
        } else if window === settingsWindow {
            // Drop the SwiftUI content so the live effect preview stops drawing; it is rebuilt
            // the next time Settings opens.
            settingsWindow?.contentViewController = nil
            settingsWindow?.contentView = nil
            settingsWindow = nil
        }
    }
}


private struct CinematicPreview: View {
    let environment: AppEnvironment
    var body: some View {
        CinematicScene(data: environment.cinematicData(), animate: environment.renderGate.canAnimateHeavy && environment.windows.canRenderCinematicPreview,
                       playerActions: environment.musicBarActions())
    }
}

private final class MusicPlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct MiniPlayerContent: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var windows = environment.windows
        MusicBar(data: environment.cinematicData(),
                 animate: environment.renderGate.canAnimate && windows.canRenderMiniPlayer,
                 isArtworkExpanded: $windows.isPlayerArtworkExpanded,
                 actions: environment.nowPlaying.currentTrack == nil ? nil : environment.musicBarActions())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(16)
            .overlay(alignment: .topTrailing) {
                Button { windows.toggleMiniPlayer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .background(.black.opacity(0.8), in: Circle())
                }
                .buttonStyle(MusicBarButtonStyle())
                .padding(5)
                .help("Close mini player")
                .accessibilityLabel("Close mini player")
            }
            .onChange(of: windows.isPlayerArtworkExpanded) { _, _ in windows.resizeMiniPlayer() }
            .onExitCommand { windows.toggleMiniPlayer() }
    }
}
