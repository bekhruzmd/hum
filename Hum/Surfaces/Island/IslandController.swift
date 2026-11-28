import AppKit
import SwiftUI

/// Owns the island panel: placement at the notch (or a pill under the menu bar), opening and
/// closing (hover with a delay, click, pull down / push up, two-finger swipes), track-change
/// peeks, and rebuilding on display changes.
@MainActor
final class IslandController {
    private unowned let environment: AppEnvironment
    private let model = IslandModel()
    private var panel: IslandPanel?
    private var openTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var scrollMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var scrollX: CGFloat = 0
    private var scrollY: CGFloat = 0
    private var scrollHandled = false
    private var isHovering = false
    private var lastTrackKey: String?

    /// How far a two-finger scroll must travel to open/close or skip, in points.
    static let scrollThreshold: CGFloat = 26
    static let swipeThreshold: CGFloat = 60

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
            controller.applyAppearanceSettings()
        }
        observeContinuously(self) { controller in
            controller.trackMaybeChanged(controller.environment.nowPlaying.currentTrack)
        }
    }

    // MARK: Settings

    private func applyAppearanceSettings() {
        let settings = environment.settings
        let size = settings.islandSize
        model.motion = settings.islandMotion
        guard size != model.size else { return }
        model.size = size
        if model.isExpanded, let geometry = model.geometry {
            panel?.setFrame(geometry.expandedFrame(content: size.expanded), display: true)
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
            !isHovering, !model.isExpanded, environment.renderGate.canAnimate
        else { return }
        peekTask?.cancel()
        let duration = environment.settings.islandPeekDuration
        peekTask = Task { [weak self] in
            // Let the panel appear and the artwork start loading first.
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            self.expand(haptic: false)
            try? await Task.sleep(for: .seconds(max(1, duration)))
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
        model.isHinting = false
        if let geometry = model.geometry {
            panel?.setFrame(geometry.collapsedFrame, display: true)
        }
    }

    private func makePanel() -> IslandPanel {
        let panel = IslandPanel()
        let interactions = IslandInteractions(
            hover: { [weak self] in self?.setHovering($0) },
            tap: { [weak self] in self?.expand(haptic: true) },
            pull: { [weak self] open in open ? self?.expand(haptic: true) : self?.collapse() }
        )
        let hosting = NSHostingView(rootView: IslandView(environment: environment, model: model, interactions: interactions))
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    private func updateVisibility() {
        let settings = environment.settings
        let shouldShow = settings.islandEnabled && environment.nowPlaying.playbackState != nil
            && environment.renderGate.canAnimate
        let showsOverFullScreen = settings.islandShowsOverFullScreen

        guard shouldShow else {
            openTask?.cancel()
            collapseTask?.cancel()
            peekTask?.cancel()
            isHovering = false
            model.isExpanded = false
            model.isHinting = false
            if let geometry = model.geometry { panel?.setFrame(geometry.collapsedFrame, display: false) }
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

    // MARK: Open / close

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering
        openTask?.cancel()
        collapseTask?.cancel()
        if hovering {
            peekTask?.cancel()
            guard !model.isExpanded else { return }
            model.isHinting = true
            guard environment.settings.islandTrigger == .hover else { return }
            // A short dwell keeps the island shut when the pointer only passes by on its way
            // to the menu bar.
            let delay = environment.settings.islandHoverDelay
            openTask = Task { [weak self] in
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                guard let self, !Task.isCancelled, self.isHovering else { return }
                self.expand(haptic: true)
            }
        } else {
            model.isHinting = false
            guard model.isExpanded else { return }
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(260))
                guard let self, !Task.isCancelled, !self.isHovering else { return }
                self.collapse()
            }
        }
    }

    private func expand(haptic: Bool) {
        guard let geometry = model.geometry, let panel, !model.isExpanded else { return }
        openTask?.cancel()
        collapseTask?.cancel()
        // Grow the panel first (transparent), then let SwiftUI spring the shape into it.
        panel.setFrame(geometry.expandedFrame(content: model.size.expanded), display: true)
        model.isHinting = false
        model.isExpanded = true
        if haptic && environment.settings.islandHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func collapse() {
        guard let geometry = model.geometry, model.isExpanded else { return }
        openTask?.cancel()
        collapseTask?.cancel()
        model.isExpanded = false
        let settle = model.motion.settleDuration
        collapseTask = Task { [weak self] in
            // Shrink the panel after the spring settles so the animation isn't clipped.
            try? await Task.sleep(for: settle)
            guard let self, !Task.isCancelled, !self.model.isExpanded else { return }
            self.panel?.setFrame(geometry.collapsedFrame, display: true)
        }
    }

    // MARK: Two-finger scrolls

    /// Over the island: swipe down to open, swipe up to close, and (when open) swipe sideways to skip.
    private func consumeScroll(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel, event.hasPreciseScrollingDeltas else { return false }
        if event.phase == .began {
            scrollX = 0
            scrollY = 0
            scrollHandled = false
        }
        scrollX += event.scrollingDeltaX
        // With natural scrolling, fingers moving down produce positive deltas.
        scrollY += event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? 1 : -1)

        if !scrollHandled {
            let vertical = abs(scrollY) > abs(scrollX)
            if vertical && !model.isExpanded && scrollY > Self.scrollThreshold {
                scrollHandled = true
                expand(haptic: true)
            } else if vertical && model.isExpanded && scrollY < -Self.scrollThreshold {
                scrollHandled = true
                collapse()
            } else if !vertical && model.isExpanded && abs(scrollX) > Self.swipeThreshold {
                scrollHandled = true
                // Fingers moving left produce negative deltas → next track.
                scrollX < 0 ? environment.nowPlaying.nextTrack() : environment.nowPlaying.previousTrack()
            }
        }
        if event.phase == .ended || event.phase == .cancelled {
            scrollX = 0
            scrollY = 0
            scrollHandled = false
        }
        return true
    }
}
