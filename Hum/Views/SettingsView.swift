import ServiceManagement
import SwiftUI

enum LyricAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

enum VisibleLinesMode: String, CaseIterable, Identifiable {
    case one
    case three
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .one: return "1 Line"
        case .three: return "3 Lines"
        case .all: return "All"
        }
    }
}

struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lyricAlignment") private var lyricAlignment: LyricAlignment = .leading
    @AppStorage("windowOpacity") private var windowOpacity: Double = 0.95
    @AppStorage("visibleLinesMode") private var visibleLinesMode: VisibleLinesMode = .all
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("preferredPlayer") private var preferredPlayer: PreferredPlayer = .auto

    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Appearance") {
                HStack {
                    Text("Font size")
                    Slider(value: $fontSize, in: 14...28, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Picker("Lyric alignment", selection: $lyricAlignment) {
                    ForEach(LyricAlignment.allCases) { alignment in
                        Text(alignment.displayName).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Visible lines", selection: $visibleLinesMode) {
                    ForEach(VisibleLinesMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Window opacity")
                    Slider(value: $windowOpacity, in: 0.35...1.0, step: 0.05)
                    Text("\(Int(windowOpacity * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Toggle("Compact subtitle mode", isOn: $compactMode)
            }

            Section("Playback & System") {
                Picker("Music player", selection: $preferredPlayer) {
                    ForEach(PreferredPlayer.allCases) { player in
                        Text(player.displayName).tag(player)
                    }
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            launchAtLoginError = error.localizedDescription
        }
    }
}
