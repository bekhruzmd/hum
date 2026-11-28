import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        let env = AppEnvironment.shared
        env.start()
        if env.settings.hasCompletedOnboarding {
            env.windows.showSettings()
        } else {
            env.windows.showOnboarding()
        }
    }

    /// Hum is a menu bar app; closing the last window must not quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopening Hum from Finder, Launchpad, or Spotlight opens the Settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppEnvironment.shared.windows.showSettings()
        return true
    }
}
