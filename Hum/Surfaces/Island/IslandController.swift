import AppKit
import SwiftUI

/// Owns the island panel: placement at the notch (or a pill under the menu bar), hover
/// expand/collapse, horizontal-swipe track skipping, and rebuilding on display changes.
@MainActor
final class IslandController {
    private unowned let environment: AppEnvironment
    private let model = IslandModel()
    private var panel: IslandPanel?
    private var collapseTask: Task<Void, Never>?
    private var scrollMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var swipeDistance: CGFloat = 0
    private var swipeHandled = false
    private var isHovering = false
    private var peekTask: Task<Void, Never>?
    private var lastTrackKey: String?

    /// How long the island stays open to announce a new track.
    static let peekDuration: Duration = .seconds(3)

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.consumeScroll(event) ?? false }
            return consumed ? nil : event
        }
        observeContinuously(self) { controller in
            controller.updateVisibility()
        }
        observeContinuously(self) { controller in
            controller.trackMaybeChanged(controller.environment.nowPlaying.currentTrack)
        }
    }

    // MARK: Peek

    /// Briefly opens the island when a new song starts, then tucks it back in.
    private func trackMaybeChanged(_ track: Track?) {
        let key = track?.cacheKey
        guard key != lastTrackKey else { return }
        let isFirst = lastTrackKey == nil
        lastTrackKey = key
        guard
            track != nil, !isFirst, environment.settings.islandPeekOnTrackChange,
            !isHovering, environment.renderGate.canAnimate
        else { return }
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            // Let the panel appear and the artwork start loading first.
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            self.expand(haptic: false)
            try? await Task.sleep(for: Self.peekDuration)
            guard !Task.isCancelled, !self.isHovering else { return }
            self.collapse()
        }
    }

    // MARK: Placement

    private static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func rebuild() {
        guard let screen = Self.targetScreen() else { return }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        model.geometry = IslandGeometry.make(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea,
            rightArea: screen.auxiliaryTopRightArea,
            menuBarHeight: menuBar > 0 ? menuBar : 24
        )
        model.isExpanded = false
        if let geometry = model.geometry {
            panel?.setFrame(geometry.collapsedFrame, display: true)
        }
    }

    private func makePanel() -> IslandPanel {
        let panel = IslandPanel()
        let root = IslandView(environment: environment, model: model) { [weak self] hovering in
            self?.setHovering(hovering)
        }
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    private func updateVisibility() {
        let settings = environment.settings
        let shouldShow = settings.islandEnabled && environment.nowPlaying.playbackState != nil
        let showsOverFullScreen = settings.islandShowsOverFullScreen

        guard shouldShow else {
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? makePanel()
        if self.panel == nil {
            self.panel = panel
            rebuild()
        }
        panel.setShowsOverFullScreenApps(showsOverFullScreen)
        panel.orderFrontRegardless()
    }

    // MARK: Hover

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering
        collapseTask?.cancel()
        if hovering {
            peekTask?.cancel()
            expand(haptic: true)
        } else {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(220))
                guard let self, !Task.isCancelled else { return }
                self.collapse()
            }
        }
    }

    private func expand(haptic: Bool) {
        guard let geometry = model.geometry, let panel, !model.isExpanded else { return }
        collapseTask?.cancel()
        panel.setFrame(geometry.expandedFrame, display: true)
        model.isExpanded = true
        if haptic {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func collapse() {
        guard let geometry = model.geometry, model.isExpanded else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            guard let self else { return }
            self.model.isExpanded = false
            // Shrink the panel after the spring settles so the animation isn't clipped.
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, !self.model.isExpanded else { return }
            self.panel?.setFrame(geometry.collapsedFrame, display: true)
        }
    }

    // MARK: Swipe

    /// Two-finger horizontal swipe over the expanded island skips tracks.
    private func consumeScroll(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel, model.isExpanded, event.hasPreciseScrollingDeltas else {
            return false
        }
        if event.phase == .began {
            swipeDistance = 0
            swipeHandled = false
        }
        swipeDistance += event.scrollingDeltaX
        if !swipeHandled, abs(swipeDistance) > 60, abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) {
            swipeHandled = true
            // Natural scrolling: fingers moving left produce negative deltas → next track.
            swipeDistance < 0 ? environment.nowPlaying.nextTrack() : environment.nowPlaying.previousTrack()
        }
        if event.phase == .ended || event.phase == .cancelled {
            swipeDistance = 0
            swipeHandled = false
        }
        return true
    }
}
