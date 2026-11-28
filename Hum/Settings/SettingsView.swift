import SwiftUI

/// The Settings window: a translucent sidebar of features (with "Off" badges) and one page per
/// feature, in the style of System Settings.
struct SettingsView: View {
    static let size = CGSize(width: 820, height: 600)
    static let sidebarWidth: CGFloat = 220

    let environment: AppEnvironment
    @State private var selection: SettingsPage
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    init(environment: AppEnvironment, initialPage: SettingsPage = .nowPlaying) {
        self.environment = environment
        _selection = State(initialValue: initialPage)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Self.sidebarWidth)
                .background(VisualEffectBackground(material: .sidebar))
            Divider()
            page(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(selection)
                .transition(.opacity)
        }
        // Fill whatever the window gives; the window owns the fixed size. A fixed frame here
        // made AppKit add the title bar's height on top of it.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .windowBackground))
        // Draw under the transparent title bar; the sidebar leaves room for the traffic lights.
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.15), value: selection)
        .background { keyboardShortcuts }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Room for the window's traffic lights.
            Color.clear.frame(height: 38)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { if let first = matches.first { selection = first } }
                    .onExitCommand { search.isEmpty ? (searchFocused = false) : (search = "") }
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if visible(.nowPlaying) { row(.nowPlaying) }
                    let features = SettingsPage.features.filter(visible)
                    if !features.isEmpty {
                        sectionLabel("Features")
                        ForEach(features) { row($0) }
                    }
                    if visible(.general) {
                        sectionLabel("Hum")
                        row(.general)
                    }
                    if matches.isEmpty {
                        VStack(spacing: 4) {
                            Text("No Results").font(.system(size: 13, weight: .semibold))
                            Text("Nothing matches “\(search)”.").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)
        }
    }

    private var matches: [SettingsPage] { SettingsPage.allCases.filter(visible) }

    /// Sidebar order, for keyboard navigation.
    private static let order: [SettingsPage] = [.nowPlaying] + SettingsPage.features + [.general]

    /// ⌘F search, ⌘1–9 pages, ⌘↑/⌘↓ previous/next page, ⌘W or Esc close. Hum has no app
    /// menu (it lives in the menu bar), so these are wired here instead.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("") { searchFocused = true }.keyboardShortcut("f")
            Button("") { environment.windows.closeSettings() }.keyboardShortcut("w")
            Button("") { if !searchFocused { environment.windows.closeSettings() } }.keyboardShortcut(.escape, modifiers: [])
            Button("") { step(-1) }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("") { step(1) }.keyboardShortcut(.downArrow, modifiers: .command)
            ForEach(Array(Self.order.prefix(9).enumerated()), id: \.offset) { index, page in
                Button("") { selection = page }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        guard let index = Self.order.firstIndex(of: selection) else { return }
        selection = Self.order[(index + delta + Self.order.count) % Self.order.count]
    }

    private func visible(_ page: SettingsPage) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return page.title.lowercased().contains(query) || page.keywords.contains(query)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    private func row(_ page: SettingsPage) -> some View {
        let selected = selection == page
        return Button {
            selection = page
        } label: {
            HStack(spacing: 9) {
                SettingsIconTile(page: page)
                Text(page.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if isOff(page) {
                    Text("Off")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 32)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.primary.opacity(0.1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(shortcutHint(page))
        .accessibilityLabel(page.title + (isOff(page) ? ", off" : ""))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func shortcutHint(_ page: SettingsPage) -> String {
        guard let index = Self.order.firstIndex(of: page), index < 9 else { return page.title }
        return "\(page.title)  ⌘\(index + 1)"
    }

    /// Features that are switched off show "Off" in the sidebar.
    private func isOff(_ page: SettingsPage) -> Bool {
        let s = environment.settings
        switch page {
        case .island: return !s.islandEnabled
        case .desktop: return s.desktopMode == .off
        case .beatGlow: return !s.beatGlowEnabled
        case .sound: return !s.needleDropSound && !s.crackleSound
        case .screenSaver: return s.idleMinutes == 0 && !s.screensaverFeed
        case .nowPlaying, .lyrics, .keys, .general: return false
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func page(_ page: SettingsPage) -> some View {
        switch page {
        case .nowPlaying: NowPlayingSettingsPage(environment: environment)
        case .island: IslandSettingsPage(settings: environment.settings)
        case .screenSaver: ScreenSaverSettingsPage(environment: environment)
        case .desktop: DesktopSettingsPage(settings: environment.settings)
        case .lyrics:
            VStack(spacing: 0) {
                SettingsPageHeader(page: .lyrics)
                LyricsSettingsTab(settings: environment.settings, palette: environment.nowPlaying.palette)
                    .scrollContentBackground(.hidden)
            }
        case .sound: SoundSettingsPage(environment: environment)
        case .beatGlow: BeatGlowSettingsPage(environment: environment)
        case .keys:
            VStack(spacing: 0) {
                SettingsPageHeader(page: .keys)
                ShortcutsSettingsTab(store: environment.hotkeyStore)
                    .scrollContentBackground(.hidden)
            }
        case .general:
            VStack(spacing: 0) {
                SettingsPageHeader(page: .general)
                GeneralSettingsTab(settings: environment.settings)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
