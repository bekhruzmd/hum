import Carbon.HIToolbox
import Foundation
import Observation

enum HotkeyAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case playPause
    case nextTrack
    case previousTrack
    case showLyrics
    case toggleDesktop
    case idleScreen
    case offsetEarlier
    case offsetLater

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playPause: return "Play / Pause"
        case .nextTrack: return "Next track"
        case .previousTrack: return "Previous track"
        case .showLyrics: return "Show / hide lyrics"
        case .toggleDesktop: return "Toggle live desktop"
        case .idleScreen: return "Start idle screen"
        case .offsetEarlier: return "Lyrics earlier (+0.1 s)"
        case .offsetLater: return "Lyrics later (−0.1 s)"
        }
    }

    /// Stable numeric id for `EventHotKeyID`.
    var hotKeyID: UInt32 { UInt32((Self.allCases.firstIndex(of: self) ?? 0) + 1) }

    static let defaults: [HotkeyAction: KeyCombo] = {
        let base = UInt32(controlKey | optionKey)
        return [
            .playPause: KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: base),
            .nextTrack: KeyCombo(keyCode: UInt32(kVK_RightArrow), carbonModifiers: base),
            .previousTrack: KeyCombo(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: base),
            .showLyrics: KeyCombo(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: base),
            .toggleDesktop: KeyCombo(keyCode: UInt32(kVK_ANSI_D), carbonModifiers: base),
            .idleScreen: KeyCombo(keyCode: UInt32(kVK_ANSI_I), carbonModifiers: base),
            .offsetEarlier: KeyCombo(keyCode: UInt32(kVK_ANSI_RightBracket), carbonModifiers: base),
            .offsetLater: KeyCombo(keyCode: UInt32(kVK_ANSI_LeftBracket), carbonModifiers: base)
        ]
    }()
}

/// The user's global shortcut bindings, persisted as JSON in `UserDefaults`.
@Observable
@MainActor
final class HotkeyStore {
    private static let key = "hotkeyBindings"
    @ObservationIgnored private let defaults: UserDefaults

    private(set) var bindings: [HotkeyAction: KeyCombo]
    /// True while the Settings recorder is capturing, so global hotkeys are paused.
    var isRecording = false
    /// The most recent shortcut used, so onboarding can notice when someone tries one.
    private(set) var lastTriggered: HotkeyAction?
    private(set) var triggerCount = 0

    func noteTriggered(_ action: HotkeyAction) {
        lastTriggered = action
        triggerCount += 1
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: KeyCombo?].self, from: data) {
            var result: [HotkeyAction: KeyCombo] = [:]
            for action in HotkeyAction.allCases {
                if let entry = saved[action.rawValue] {
                    if let combo = entry { result[action] = combo }
                } else if let fallback = HotkeyAction.defaults[action] {
                    result[action] = fallback
                }
            }
            bindings = result
        } else {
            bindings = HotkeyAction.defaults
        }
    }

    /// Binds `combo` to `action` (nil clears). A combo already used elsewhere is moved here.
    func set(_ combo: KeyCombo?, for action: HotkeyAction) {
        if let combo {
            for (other, existing) in bindings where existing == combo && other != action {
                bindings[other] = nil
            }
        }
        bindings[action] = combo
        save()
    }

    func resetToDefaults() {
        bindings = HotkeyAction.defaults
        save()
    }

    private func save() {
        var encoded: [String: KeyCombo?] = [:]
        for action in HotkeyAction.allCases {
            encoded[action.rawValue] = .some(bindings[action])
        }
        if let data = try? JSONEncoder().encode(encoded) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
