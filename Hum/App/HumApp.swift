import AppKit
import SwiftUI

@main
struct HumApp: App {
    @State private var nowPlayingStore = NowPlayingStore()
    @State private var lyricsStore = LyricsStore()
    @State private var isFloating = true
    @State private var mainWindow: NSWindow?

    @AppStorage("windowOpacity") private var windowOpacity: Double = 0.95
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("preferredPlayer") private var preferredPlayer: PreferredPlayer = .auto

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Hum", id: "lyrics") {
            ContentView(
                nowPlayingStore: nowPlayingStore,
                lyricsStore: lyricsStore
            )
            .background(
                WindowAccessor(isFloating: isFloating, opacity: windowOpacity) { window in
                    mainWindow = window
                }
            )
            .onAppear {
                nowPlayingStore.preferredPlayer = preferredPlayer
                nowPlayingStore.startPolling()
            }
            .onChange(of: preferredPlayer) { _, newValue in
                nowPlayingStore.preferredPlayer = newValue
                nowPlayingStore.pollOnce()
            }
            .onChange(of: nowPlayingStore.currentTrack) { _, newTrack in
                lyricsStore.update(for: newTrack)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 480)

        Settings {
            SettingsView()
        }

        MenuBarExtra("Hum", systemImage: "music.note") {
            Button(isWindowVisible ? "Hide Window" : "Show Window") {
                toggleWindow()
            }

            Toggle("Float on Top", isOn: $isFloating)
            Toggle("Compact Subtitle Mode", isOn: $compactMode)

            Divider()

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Hum") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var isWindowVisible: Bool {
        mainWindow?.isVisible ?? true
    }

    private func toggleWindow() {
        if let window = mainWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            openWindow(id: "lyrics")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
