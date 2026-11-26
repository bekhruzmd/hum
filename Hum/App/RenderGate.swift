import AppKit
import Observation

/// App-wide "may we animate?" signal. Surfaces stop animating when the screen is locked,
/// the displays sleep, the screensaver runs, or Low Power Mode is on.
@Observable
@MainActor
final class RenderGate {
    private(set) var isScreenLocked = false
    private(set) var areScreensAsleep = false
    private(set) var isScreensaverRunning = false
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    var canAnimate: Bool { !isScreenLocked && !areScreensAsleep && !isScreensaverRunning }
    /// Heavier surfaces (desktop, idle screen) also respect Low Power Mode.
    var canAnimateHeavy: Bool { canAnimate && !isLowPowerMode }

    @ObservationIgnored private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    func start() {
        guard tokens.isEmpty else { return }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked") { $0.isScreenLocked = true }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.isScreenLocked = false }
        observe(distributed, "com.apple.screensaver.didstart") { $0.isScreensaverRunning = true }
        observe(distributed, "com.apple.screensaver.didstop") { $0.isScreensaverRunning = false }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification.rawValue) { $0.areScreensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue) { $0.areScreensAsleep = false }

        observe(.default, Notification.Name.NSProcessInfoPowerStateDidChange.rawValue) {
            $0.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ update: @escaping @MainActor (RenderGate) -> Void) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                update(self)
            }
        }
        tokens.append((center, token))
    }
}
