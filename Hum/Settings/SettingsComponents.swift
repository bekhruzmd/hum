import AppKit
import SwiftUI

/// Every page in the Settings sidebar.
enum SettingsPage: String, CaseIterable, Identifiable {
    case nowPlaying
    case island
    case screenSaver
    case desktop
    case lyrics
    case sound
    case beatGlow
    case keys
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .island: return "Island"
        case .screenSaver: return "Screen Saver"
        case .desktop: return "Desktop"
        case .lyrics: return "Lyrics"
        case .sound: return "Sound"
        case .beatGlow: return "Beat Glow"
        case .keys: return "Keys"
        case .general: return "General"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .island: return "capsule.fill"
        case .screenSaver: return "moon.stars.fill"
        case .desktop: return "record.circle"
        case .lyrics: return "quote.bubble.fill"
        case .sound: return "slider.vertical.3"
        case .beatGlow: return "waveform"
        case .keys: return "keyboard"
        case .general: return "gearshape.fill"
        }
    }

    /// Icon tile colors.
    var tint: [Color] {
        switch self {
        case .nowPlaying: return [Color(red: 1, green: 0.36, blue: 0.42), Color(red: 0.9, green: 0.16, blue: 0.3)]
        case .island: return [Color(white: 0.32), Color(white: 0.12)]
        case .screenSaver: return [Color(red: 0.42, green: 0.36, blue: 0.95), Color(red: 0.25, green: 0.2, blue: 0.7)]
        case .desktop: return [Color(red: 0.98, green: 0.62, blue: 0.2), Color(red: 0.9, green: 0.38, blue: 0.1)]
        case .lyrics: return [Color(red: 0.2, green: 0.78, blue: 0.5), Color(red: 0.1, green: 0.58, blue: 0.36)]
        case .sound: return [Color(red: 0.3, green: 0.62, blue: 1), Color(red: 0.14, green: 0.4, blue: 0.9)]
        case .beatGlow: return [Color(red: 0.95, green: 0.35, blue: 0.85), Color(red: 0.45, green: 0.3, blue: 1)]
        case .keys: return [Color(white: 0.55), Color(white: 0.35)]
        case .general: return [Color(white: 0.6), Color(white: 0.4)]
        }
    }

    /// Extra words the sidebar search matches.
    var keywords: String {
        switch self {
        case .nowPlaying: return "track song player source offset"
        case .island: return "notch hover pull animation haptic peek liquid glass material frosted"
        case .screenSaver: return "idle lock screen player bar record controls install"
        case .desktop: return "wallpaper turntable cinematic"
        case .lyrics: return "effect font window menu bar karaoke constellation"
        case .sound: return "needle crackle volume"
        case .beatGlow: return "edge light color spectrum pulse orbit display calibration"
        case .keys: return "shortcuts hotkeys"
        case .general: return "login privacy about appearance liquid glass material"
        }
    }

    static let features: [SettingsPage] = [.island, .screenSaver, .desktop, .lyrics, .sound, .beatGlow, .keys]
}

/// A rounded, colored square holding a white symbol, like System Settings.
struct SettingsIconTile: View {
    let page: SettingsPage
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(LinearGradient(colors: page.tint, startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: page.symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

/// Page header: icon and large title.
struct SettingsPageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 10) {
            SettingsIconTile(page: page, size: 30)
            Text(page.title)
                .font(.system(size: 22, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A page: header plus a grouped form whose background shows the window's material.
struct SettingsPageScaffold<Content: View>: View {
    let page: SettingsPage
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(page: page)
            Form { content }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
        }
    }
}

/// A prominent on/off row with a caption, like "Record and Player — On the lock screen…".
struct FeatureToggleRow: View {
    let title: String
    let caption: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 3)
    }
}

/// A rounded preview well with a fixed size, so animated content can never resize the page.
struct PreviewWell<Content: View>: View {
    var height: CGFloat = 200
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .padding(.vertical, 4)
    }
}

/// `NSVisualEffectView` for sidebar and window materials.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

extension RGB {
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent))
    }
}
