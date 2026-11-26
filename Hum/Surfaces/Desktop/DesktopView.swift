import SwiftUI

enum DesktopMode: String, CaseIterable, Identifiable {
    case off
    case lyrics
    case cinematic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .lyrics: return "Lyrics"
        case .cinematic: return "Cinematic"
        }
    }
}

enum DesktopLyricsBackground: String, CaseIterable, Identifiable {
    case wallpaper
    case album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wallpaper: return "My wallpaper"
        case .album: return "Blurred album colors"
        }
    }
}

@Observable
@MainActor
final class DesktopWindowModel {
    /// False while the window is fully covered (occlusion), so it stops animating.
    var isVisible = true
}

/// Content of one desktop-level window.
struct DesktopView: View {
    let environment: AppEnvironment
    let model: DesktopWindowModel

    private var settings: SettingsStore { environment.settings }
    private var nowPlaying: NowPlayingStore { environment.nowPlaying }
    private var animate: Bool { model.isVisible && environment.renderGate.canAnimateHeavy }

    var body: some View {
        GeometryReader { proxy in
            switch settings.desktopMode {
            case .off:
                Color.clear
            case .lyrics:
                DesktopLyricsView(environment: environment, animate: animate, size: proxy.size)
            case .cinematic:
                CinematicScene(data: environment.cinematicData(), animate: animate)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

private struct DesktopLyricsView: View {
    let environment: AppEnvironment
    let animate: Bool
    let size: CGSize

    var body: some View {
        let nowPlaying = environment.nowPlaying
        let fontSize = max(28, size.height * 0.045)
        ZStack {
            if environment.settings.desktopLyricsBackground == .album {
                albumBackground
            }
            if let state = nowPlaying.playbackState {
                let lines = environment.lyrics.timedLines
                TimelineView(.animation(minimumInterval: 0.1, paused: !(animate && state.isPlaying))) { timeline in
                    let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
                    VStack(spacing: fontSize * 0.6) {
                        if let index {
                            LiveLyricEffect(
                                kind: environment.settings.lyricEffect,
                                line: lines[index],
                                palette: nowPlaying.palette,
                                fontSize: fontSize,
                                alignment: .center,
                                isPlaying: animate && state.isPlaying,
                                lyricTime: { environment.lyricTime(state, at: $0) }
                            )
                            .id(index)
                            .transition(.opacity.combined(with: .offset(y: fontSize * 0.4)))
                            if index + 1 < lines.count {
                                Text(lines[index + 1].displayText)
                                    .font(.system(size: fontSize * 0.55, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .multilineTextAlignment(.center)
                                    .id("next-\(index)")
                                    .transition(.opacity)
                            }
                        } else {
                            Text("\(state.track.title) — \(state.track.artist)")
                                .font(.system(size: fontSize * 0.6, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .animation(.easeInOut(duration: 0.35), value: index)
                }
                .frame(maxWidth: size.width * 0.7)
                .shadow(color: .black.opacity(0.55), radius: fontSize * 0.25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, size.height * 0.16)
            }
        }
    }

    @ViewBuilder
    private var albumBackground: some View {
        let nowPlaying = environment.nowPlaying
        if let blurred = BlurredArtwork.image(for: nowPlaying.artworkImage) {
            Image(nsImage: blurred)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            LinearGradient(
                colors: [nowPlaying.palette.primary, nowPlaying.palette.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
