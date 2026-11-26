import SwiftUI

/// The Settings window tabs.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics"
    case display = "Display"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "text.quote"
        case .display: return "display"
        case .shortcuts: return "command"
        }
    }
}

/// The Settings window: cleanly structured into 4 essential tabs with custom native macOS navigation.
struct SettingsView: View {
    static let size = CGSize(width: 540, height: 580)

    let environment: AppEnvironment
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // macOS-native clean segmented tab picker with ample breathing room
            HStack {
                Spacer()
                Picker("", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Active Tab Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(settings: environment.settings)
                case .lyrics:
                    LyricsSettingsTab(settings: environment.settings, palette: environment.nowPlaying.palette)
                case .display:
                    IdleSoundsSettingsTab(environment: environment)
                case .shortcuts:
                    ShortcutsSettingsTab(store: environment.hotkeyStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
