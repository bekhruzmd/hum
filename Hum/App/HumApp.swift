import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Hum", systemImage: "music.note") {
            MenuBarContent(environment: AppEnvironment.shared)
        }
    }
}
