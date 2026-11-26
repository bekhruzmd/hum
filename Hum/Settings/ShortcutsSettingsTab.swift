import AppKit
import SwiftUI

struct ShortcutsSettingsTab: View {
    let store: HotkeyStore

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    LabeledContent(action.displayName) {
                        ShortcutRecorder(store: store, action: action)
                    }
                }
            } footer: {
                HStack {
                    Text("Shortcuts work in any app. Click a shortcut, then press the new keys (⌘, ⌃ or ⌥ required). ⎋ cancels, ⌫ clears.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Defaults") { store.resetToDefaults() }
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Click to record a new global shortcut for one action.
struct ShortcutRecorder: View {
    let store: HotkeyStore
    let action: HotkeyAction

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            Text(isRecording ? "Press keys…" : (store.bindings[action]?.displayString ?? "None"))
                .monospacedDigit()
                .frame(minWidth: 96)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : nil)
        .accessibilityLabel("\(action.displayName) shortcut")
        .accessibilityValue(store.bindings[action]?.displayString ?? "None")
        .onDisappear(perform: stop)
    }

    private func start() {
        stop()
        isRecording = true
        store.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { record(keyCode: event.keyCode, flags: event.modifierFlags) }
            return nil
        }
    }

    private func record(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        let relevant = flags.intersection([.command, .option, .control, .shift])
        if relevant.isEmpty && keyCode == 53 { // Escape
            stop()
            return
        }
        if relevant.isEmpty && (keyCode == 51 || keyCode == 117) { // Delete / Forward Delete
            store.set(nil, for: action)
            stop()
            return
        }
        let combo = KeyCombo(keyCode: keyCode, flags: relevant)
        guard combo.hasRequiredModifier else {
            NSSound.beep()
            return
        }
        store.set(combo, for: action)
        stop()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { store.isRecording = false }
        isRecording = false
    }
}
