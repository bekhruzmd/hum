import ScreenSaver
import SwiftUI

/// The Hum screensaver: the cinematic scene with live lyrics, fed by the Hum app.
@objc(HumSaverView)
final class HumSaverView: ScreenSaverView {
    private let model = SaverModel()
    private var stopObserver: NSObjectProtocol?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        model.start()
        // SwiftUI drives its own animation; the ScreenSaver timer only needs to tick rarely.
        animationTimeInterval = 1.0 / 30.0
        let hosting = NSHostingView(rootView: SaverRoot(model: model))
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)

        // macOS sometimes keeps the screensaver process running after it's dismissed; stop
        // drawing as soon as the system says the screensaver is going away.
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.stop() }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            model.start()
        }
    }

    // Allow clicks to reach the SwiftUI music bar controls instead of dismissing the saver.
    override func mouseDown(with event: NSEvent) {
        // Let SwiftUI handle it; don't call super (which would dismiss the screensaver).
    }
    override func mouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}

    deinit {
        if let stopObserver {
            DistributedNotificationCenter.default().removeObserver(stopObserver)
        }
    }

    override func startAnimation() {
        super.startAnimation()
        model.start()
    }

    override func stopAnimation() {
        super.stopAnimation()
        model.stop()
    }

    override func animateOneFrame() {
        if !model.isRunning {
            model.start()
        }
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}

private struct SaverRoot: View {
    let model: SaverModel

    var body: some View {
        CinematicScene(data: model.sceneData, animate: true, playerActions: nil)
    }
}
