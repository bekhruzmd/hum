import SwiftUI

/// Track text shown in the scene. Codable so the screensaver feed can carry it.
struct SceneTrackInfo: Equatable, Codable, Sendable {
    var title: String
    var artist: String
    var album: String
}

/// Everything the cinematic scene draws. Deliberately independent of the app's stores so the
/// same view runs inside Hum and inside the Hum screensaver.
struct CinematicSceneData {
    var track: SceneTrackInfo?
    var artwork: NSImage?
    var palette: AlbumPalette = .fallback
    var lines: [TimedLine] = []
    var effect: LyricEffectKind = .constellation
    var isPlaying = false
    /// Lyric time (position + offset) at a date.
    var lyricTime: (Date) -> TimeInterval = { _ in 0 }
}

/// A dark, monochrome full-screen music scene: the cover in black and white drifting slowly,
/// soft smoke, a thin poster frame with the album title, a serif clock, and the lyrics in the
/// chosen effect (Constellation by default).
struct CinematicScene: View {
    let data: CinematicSceneData
    /// False stops every animation (covered, locked, Low Power, paused screensaver).
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black
                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !animate)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        artwork(size: size, time: t)
                        SmokeLayer(time: t)
                            .blendMode(.screen)
                            .opacity(0.9)
                    }
                }
                vignette
                PosterFrame(album: data.track?.album ?? "", size: size)
                clock(size: size)
                lyrics(size: size)
                trackCaption(size: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }

    // MARK: Layers

    @ViewBuilder
    private func artwork(size: CGSize, time t: TimeInterval) -> some View {
        if let mono = MonochromeArtwork.image(for: data.artwork) {
            // Slow drift and breathe, like a camera move.
            let scale = 1.14 + 0.04 * sin(t * 0.045)
            Image(nsImage: mono)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(x: CGFloat(sin(t * 0.031)) * size.width * 0.025, y: CGFloat(cos(t * 0.027)) * size.height * 0.02)
                .opacity(0.82)
        } else {
            RadialGradient(colors: [Color(white: 0.22), .black], center: .center, startRadius: 0, endRadius: size.width * 0.6)
        }
    }

    private var vignette: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.35), .black.opacity(0.85)],
            center: .center,
            startRadius: 0,
            endRadius: 900
        )
        .scaleEffect(1.4)
        .allowsHitTesting(false)
    }

    private func clock(size: CGSize) -> some View {
        let h = size.height
        return TimelineView(.everyMinute) { timeline in
            VStack(spacing: h * 0.004) {
                Text(timeline.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.system(size: h * 0.02, weight: .regular, design: .serif))
                    .opacity(0.85)
                Text(timeline.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: h * 0.085, weight: .regular, design: .serif))
                    .monospacedDigit()
            }
            .shadow(color: .black.opacity(0.5), radius: 12)
        }
        .position(x: size.width / 2, y: size.height * 0.23)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func lyrics(size: CGSize) -> some View {
        let lines = data.lines
        if !lines.isEmpty {
            let fontSize = max(16, size.height * 0.03)
            TimelineView(.animation(minimumInterval: 0.1, paused: !(animate && data.isPlaying))) { timeline in
                let index = lines.activeIndex(at: data.lyricTime(timeline.date))
                Group {
                    if let index {
                        LiveLyricEffect(
                            kind: data.effect,
                            line: lines[index],
                            palette: data.palette,
                            fontSize: fontSize,
                            alignment: .leading,
                            isPlaying: animate && data.isPlaying,
                            previous: index > 0 ? lines[index - 1] : nil,
                            lyricTime: data.lyricTime
                        )
                    }
                }
                .id(index ?? -1)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: index)
            }
            .frame(width: size.width * 0.56)
            .shadow(color: .black.opacity(0.6), radius: 10)
            .position(x: size.width * 0.44, y: size.height * 0.66)
        }
    }

    private func trackCaption(size: CGSize) -> some View {
        Group {
            if let track = data.track {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: size.height * 0.016, weight: .semibold, design: .serif))
                    Text(track.artist)
                        .font(.system(size: size.height * 0.014, weight: .regular, design: .serif))
                        .opacity(0.7)
                }
                .opacity(0.75)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(size.height * 0.045)
    }
}

/// A thin frame around the middle of the screen, broken at the top for the album title.
private struct PosterFrame: View {
    let album: String
    let size: CGSize

    var body: some View {
        Canvas { canvas, canvasSize in
            let w = canvasSize.width, h = canvasSize.height
            let rect = CGRect(x: w * 0.31, y: h * 0.1, width: w * 0.38, height: h * 0.8)
            let lineWidth = max(1.5, h * 0.0022)
            let title = canvas.resolve(
                Text(album.uppercased())
                    .font(.system(size: h * 0.042, weight: .bold, design: .serif))
                    .tracking(h * 0.002)
                    .foregroundColor(.white)
            )
            let titleSize = album.isEmpty ? .zero : title.measure(in: CGSize(width: rect.width * 0.9, height: h))
            let gap = titleSize.width > 0 ? titleSize.width + h * 0.03 : 0

            var path = Path()
            path.move(to: CGPoint(x: rect.midX - gap / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + gap / 2, y: rect.minY))
            canvas.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: lineWidth)
            if !album.isEmpty {
                canvas.draw(title, at: CGPoint(x: rect.midX, y: rect.minY), anchor: .center)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.4), radius: 8)
        .allowsHitTesting(false)
    }
}

/// Soft drifting wisps of smoke: stretched radial gradients only (no blur filters).
struct SmokeLayer: View {
    let time: TimeInterval

    private static let wisps: [(x: Double, y: Double, w: Double, h: Double, speed: Double, phase: Double, alpha: Double)] = [
        (0.20, 0.30, 0.75, 0.20, 0.021, 0.0, 0.10),
        (0.75, 0.55, 0.85, 0.18, 0.017, 1.7, 0.09),
        (0.45, 0.80, 0.90, 0.22, 0.025, 3.1, 0.08),
        (0.60, 0.15, 0.60, 0.14, 0.019, 4.4, 0.07),
        (0.10, 0.70, 0.55, 0.16, 0.023, 5.6, 0.08),
        (0.88, 0.25, 0.50, 0.15, 0.015, 2.4, 0.06)
    ]

    var body: some View {
        Canvas { canvas, size in
            for wisp in Self.wisps {
                let t = time * wisp.speed + wisp.phase
                let center = CGPoint(
                    x: size.width * (wisp.x + 0.12 * sin(t * 1.4)),
                    y: size.height * (wisp.y + 0.06 * cos(t))
                )
                let w = size.width * wisp.w, h = size.height * wisp.h
                var layer = canvas
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .radians(0.35 * sin(t * 0.7) + wisp.phase))
                layer.scaleBy(x: 1, y: h / w)
                let rect = CGRect(x: -w / 2, y: -w / 2, width: w, height: w)
                layer.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(wisp.alpha), .white.opacity(wisp.alpha * 0.4), .clear]),
                        center: .zero, startRadius: 0, endRadius: w / 2
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}
