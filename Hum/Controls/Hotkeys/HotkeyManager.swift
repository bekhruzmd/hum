import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys with Carbon `RegisterEventHotKey` (no Accessibility permission
/// needed) and re-registers whenever the bindings change.
@MainActor
final class HotkeyManager {
    private static let signature: OSType = 0x48554D4B // "HUMK"

    private let store: HotkeyStore
    private let perform: (HotkeyAction) -> Void
    private var registered: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    init(store: HotkeyStore, perform: @escaping (HotkeyAction) -> Void) {
        self.store = store
        self.perform = perform
    }

    func start() {
        installHandler()
        observeContinuously(self) { manager in
            let bindings = manager.store.bindings
            let paused = manager.store.isRecording
            manager.register(paused ? [:] : bindings)
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let id = hotKeyID.id
            // Carbon delivers application events on the main thread.
            MainActor.assumeIsolated { manager.handle(id: id) }
            return noErr
        }, 1, &spec, context, &handler)
    }

    private func register(_ bindings: [HotkeyAction: KeyCombo]) {
        registered.forEach { UnregisterEventHotKey($0) }
        registered.removeAll()
        for (action, combo) in bindings {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: action.hotKeyID)
            let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered.append(ref)
            }
        }
    }

    private func handle(id: UInt32) {
        guard let action = HotkeyAction.allCases.first(where: { $0.hotKeyID == id }) else { return }
        perform(action)
    }
}
