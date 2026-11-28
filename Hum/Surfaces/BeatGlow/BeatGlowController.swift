import AppKit
import SwiftUI

/// Beat Glow: a line of light around every display's edge while music plays, flaring on each
/// sung word. One transparent, click-through window per display, above normal windows.
///
/// Windows exist only while the glow is on and music plays; the shader timeline pauses when
/// the screen is locked, asleep, or covered by the idle scene.
@MainActor
final class BeatGlowController {
    private unowned let environment: AppEnvironment
    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var isShown = false

    /// Above apps, the Dock and the menu bar; below the island, idle scene and screensaver.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isShown else { return }
                self.tearDown()
                self.build()
            }
        }
        observeContinuously(self) { controller in
            let env = controller.environment
            let shouldShow = env.settings.beatGlowEnabled && env.nowPlaying.isPlaying && env.renderGate.canAnimate
            controller.setShown(shouldShow)
        }
    }

    private func setShown(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        shown ? build() : fadeOutAndTearDown()
    }

    private func build() {
        windows = NSScreen.screens.map(makeWindow)
    }

    private func tearDown() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func fadeOutAndTearDown() {
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.6
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        let geometry = DisplayEdgeGeometry.read(screen)
        window.contentView = NSHostingView(rootView: BeatGlowView(environment: environment, display: geometry))
        window.setFrame(screen.frame, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8
            window.animator().alphaValue = 1
        }
        return window
    }
}

/// The glow for one display, driven by the current song's lyric timing.
struct BeatGlowView: View {
    let environment: AppEnvironment
    let display: DisplayEdgeGeometry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        let settings = environment.settings
        let nowPlaying = environment.nowPlaying
        let appearance = settings.glowAppearance
        let lines = environment.lyrics.timedLines
        let animate = nowPlaying.isPlaying && environment.renderGate.canAnimate && !reduceMotion
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { timeline in
                let lyricTime = nowPlaying.playbackState.map { environment.lyricTime($0, at: timeline.date) } ?? 0
                DisplayEdgeGlow(
                    contour: display.resolved(settings.displayEdgeProfiles[display.id] ?? .init(), in: proxy.size),
                    time: timeline.date.timeIntervalSince(start),
                    intensity: settings.beatGlowIntensity,
                    color: appearance.color(for: nowPlaying.palette),
                    appearance: appearance,
                    pulse: BeatPulse.value(lines: lines, time: lyricTime, isPlaying: animate,
                                           followsLyrics: appearance.followsLyrics)
                )
            }
        }
        .ignoresSafeArea()
    }
}
