import AppKit
import SwiftUI

/// Owns the island panel: placement at the notch (or a pill under the menu bar), opening and
/// closing (hover with a delay, click, pull down / push up, two-finger swipes), pages,
/// track-change peeks, and rebuilding on display changes.
///
/// The panel has a fixed size, large enough for the biggest open island, and never resizes:
/// opening and closing are pure SwiftUI springs, so they can be interrupted and reversed at
/// any moment. The panel ignores mouse events except while the pointer is over the island
/// itself, so the transparent area around it never steals clicks from the menu bar. Hover is
/// decided from screen geometry rather than view tracking areas, so it can't flicker.
@MainActor
final class IslandController {
    private unowned let environment: AppEnvironment
    private let model = IslandModel()
    private var panel: IslandPanel?
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var pointerPoll: Task<Void, Never>?
    private var scrollMonitor: Any?
    private var pointerMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var scrollX: CGFloat = 0
    private var scrollY: CGFloat = 0
    private var scrollHandled = false
    private var isHovering = false
    private var lastTrackKey: String?

    /// How far a two-finger scroll must travel to open/close or change page, in points.
    static let scrollThreshold: CGFloat = 26
    static let pageSwipeThreshold: CGFloat = 50
    /// Grace period before closing when the pointer leaves, so brief exits don't snap it shut.
    static let closeDelay: Duration = .milliseconds(240)

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
            controller.model.motion = controller.environment.settings.islandMotion
            controller.model.size = controller.environment.settings.islandSize
            if !controller.environment.settings.islandShowsLyrics { controller.model.page = .player }
        }
        observeContinuously(self) { controller in
            controller.trackMaybeChanged(controller.environment.nowPlaying.currentTrack)
        }
    }

    // MARK: Placement

    private static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func rebuild() {
        guard let screen = Self.targetScreen() else { return }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let geometry = IslandGeometry.make(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea,
            rightArea: screen.auxiliaryTopRightArea,
            menuBarHeight: menuBar > 0 ? menuBar : 24
        )
        model.geometry = geometry
        model.isExpanded = false
        model.isHinting = false
        panel?.setFrame(geometry.panelFrame(maxContent: IslandSize.large.expanded), display: true)
        panel?.ignoresMouseEvents = true
    }

    private func makePanel() -> IslandPanel {
        let panel = IslandPanel()
        panel.ignoresMouseEvents = true
        let interactions = IslandInteractions(
            tap: { [weak self] in self?.expand(haptic: true) },
            pull: { [weak self] open in open ? self?.expand(haptic: true) : self?.collapse() },
            selectPage: { [weak self] page in self?.select(page) }
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
            closeTask?.cancel()
            peekTask?.cancel()
            stopPointerTracking()
            isHovering = false
            model.isExpanded = false
            model.isHinting = false
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? makePanel()
        if self.panel == nil {
            self.panel = panel
            rebuild()
        }
        panel.setShowsOverFullScreenApps(showsOverFullScreen)
        if !panel.isVisible {
            panel.orderFrontRegardless()
            startPointerTracking()
        }
    }

    // MARK: Pointer tracking

    /// Mouse-moved events from other apps (global) and from Hum (local) tell us when the
    /// pointer reaches the island. While it's over the island, a light poll watches for the
    /// exit, since a non-key panel doesn't get reliable mouse-moved events of its own.
    private func startPointerTracking() {
        guard pointerMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }) {
            pointerMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }) {
            pointerMonitors.append(local)
        }
    }

    private func stopPointerTracking() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors.removeAll()
        pointerPoll?.cancel()
        pointerPoll = nil
    }

    private func pointerMoved() {
        guard let geometry = model.geometry, let panel, panel.isVisible else { return }
        let inside = geometry.hitRect(open: model.isExpanded, content: model.size.expanded)
            .contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        if inside != isHovering { setHovering(inside) }
        if inside && pointerPoll == nil {
            pointerPoll = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard let self, !Task.isCancelled else { return }
                    self.pointerMoved()
                    if !self.isHovering {
                        self.pointerPoll = nil
                        return
                    }
                }
            }
        }
    }

    // MARK: Open / close

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering
        openTask?.cancel()
        closeTask?.cancel()
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
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: Self.closeDelay)
                guard let self, !Task.isCancelled, !self.isHovering else { return }
                self.collapse()
            }
        }
    }

    private func expand(haptic: Bool) {
        guard model.geometry != nil, !model.isExpanded else { return }
        openTask?.cancel()
        closeTask?.cancel()
        model.isHinting = false
        model.isExpanded = true
        if haptic && environment.settings.islandHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        // The hit area just grew; re-evaluate so the panel accepts clicks under the pointer.
        pointerMoved()
    }

    private func collapse() {
        guard model.isExpanded else { return }
        openTask?.cancel()
        closeTask?.cancel()
        model.isExpanded = false
        pointerMoved()
    }

    private func select(_ page: IslandPage) {
        guard page != model.page else { return }
        model.pageDirection = page.rawValue > model.page.rawValue ? 1 : -1
        model.page = page
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
            // Let the artwork start loading first.
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            self.select(.player)
            self.expand(haptic: false)
            try? await Task.sleep(for: .seconds(max(1, duration)))
            guard !Task.isCancelled, !self.isHovering else { return }
            self.collapse()
        }
    }

    // MARK: Two-finger scrolls

    /// Over the island: swipe down to open, swipe up to close; when open, swipe sideways to
    /// change page.
    private func consumeScroll(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel, event.hasPreciseScrollingDeltas else { return false }
        if event.phase == .began {
            scrollX = 0
            scrollY = 0
            scrollHandled = false
        }
        scrollX += event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? 1 : -1)
        // Normalize so fingers moving down are positive whatever the scrolling preference.
        scrollY += event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? 1 : -1)

        if !scrollHandled {
            let vertical = abs(scrollY) > abs(scrollX)
            if vertical && !model.isExpanded && scrollY > Self.scrollThreshold {
                scrollHandled = true
                expand(haptic: true)
            } else if vertical && model.isExpanded && scrollY < -Self.scrollThreshold {
                scrollHandled = true
                collapse()
            } else if !vertical && model.isExpanded && environment.settings.islandShowsLyrics
                        && abs(scrollX) > Self.pageSwipeThreshold {
                scrollHandled = true
                // Fingers moving left reveal the next page, like a carousel.
                select(scrollX < 0 ? .lyrics : .player)
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
