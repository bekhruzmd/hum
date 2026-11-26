import SwiftUI

/// Full-screen music idle view with blurred artwork and live lyrics.
struct IdleScreenView: View {
    let environment: AppEnvironment

    private var nowPlaying: NowPlayingStore { environment.nowPlaying }
    private var animate: Bool { environment.renderGate.canAnimateHeavy }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack {
                background(size: proxy.size)

                VStack(spacing: h * 0.03) {
                    ArtworkView(image: nowPlaying.artworkImage, size: h * 0.3, cornerRadius: h * 0.02)
                        .shadow(color: .black.opacity(0.5), radius: h * 0.03, y: h * 0.015)
                    if let track = nowPlaying.currentTrack {
                        VStack(spacing: 6) {
                            Text(track.title)
                                .font(.system(size: h * 0.032, weight: .bold, design: .rounded))
                            Text(track.artist)
                                .font(.system(size: h * 0.022, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    }
                    lyric(fontSize: h * 0.04)
                        .frame(maxWidth: proxy.size.width * 0.7, minHeight: h * 0.12)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -h * 0.04)

            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [nowPlaying.palette.primary, nowPlaying.palette.secondary, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let blurred = BlurredArtwork.image(for: nowPlaying.artworkImage) {
                Image(nsImage: blurred)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(0.85)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private func lyric(fontSize: CGFloat) -> some View {
        if let state = nowPlaying.playbackState {
            let lines = environment.lyrics.timedLines
            TimelineView(.animation(minimumInterval: 0.1, paused: !(animate && state.isPlaying))) { timeline in
                let index = lines.activeIndex(at: environment.lyricTime(state, at: timeline.date))
                Group {
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
                    } else {
                        Color.clear
                    }
                }
                .id(index ?? -1)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: index)
            }
        }
    }

}
