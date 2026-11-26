import SwiftUI

/// Track text shown in the scene. Codable so the screensaver feed can carry it.
struct SceneTrackInfo: Equatable, Codable, Sendable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval? = nil
}

/// Everything the cinematic scene draws. Deliberately independent of the app's stores so the
/// same view runs inside Hum and inside the Hum screensaver.
struct CinematicSceneData {
    var track: SceneTrackInfo?
    var artwork: NSImage?
    var palette: AlbumPalette = .fallback
    var lines: [TimedLine] = []
    var effect: LyricEffectKind = .constellation
    var look: CinematicLook = .album
    var edgeGlow: Double = 1
    var displayEdgeProfiles: [String: DisplayEdgeProfile] = [:]
    var isPlaying = false
    var isShuffling: Bool? = nil
    var statusMessage: String?
    var playbackPosition: (Date) -> TimeInterval = { _ in 0 }
    /// Lyric time (position + offset) at a date.
    var lyricTime: (Date) -> TimeInterval = { _ in 0 }
}

/// Immersive music artwork with live constellation lyrics and adjustable drifting edge light.
struct CinematicScene: View {
    let data: CinematicSceneData
    let animate: Bool
    var playerActions: MusicBarActions? = nil
    var displayOverride: DisplayEdgeGeometry? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayGeometry = DisplayEdgeGeometry()
    @State private var animationStart = Date()
    @State private var isArtworkExpanded = false

    private var trackIdentity: String {
        [data.track?.title, data.track?.artist, data.track?.album].compactMap { $0 }.joined(separator: "\u{1F}")
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let unit = min(size.height, size.width * 0.8)
            let display = displayOverride ?? displayGeometry
            let contour = display.resolved(data.displayEdgeProfiles[display.id] ?? .init(), in: size)
            ZStack {
                Color.black
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate || reduceMotion)) { timeline in
                    let time = Float(timeline.date.timeIntervalSince(animationStart))
                    ZStack {
                        artwork(size: size, unit: unit)
                        .layerEffect(
                            ShaderLibrary.bundle(Bundle(for: CinematicShaderBundle.self)).humRefraction(
                                .float2(Float(size.width), Float(size.height)), .float(time)),
                            maxSampleOffset: CGSize(width: unit * 0.045, height: unit * 0.045),
                            isEnabled: !reduceMotion && animate)
                        CinematicLight(time: reduceMotion ? 0 : Double(time),
                                       hasArtwork: data.look == .monochrome && data.artwork != nil)
                        LinearGradient(colors: [.black.opacity(0.30), .clear, .black.opacity(0.20)], startPoint: .top, endPoint: .bottom)
                        let glowRGB = data.palette.dominantGlowColor
                        DisplayEdgeGlow(contour: contour, time: reduceMotion ? 0 : Double(time),
                                        intensity: data.edgeGlow, color: glowRGB)
                    }
                    .frame(width: size.width, height: size.height)
                }
                .allowsHitTesting(false)
                if data.look == .monochrome {
                    title(unit: unit)
                        .position(x: size.width * 0.5, y: size.height * 0.065)
                }
                lyrics(size: size, unit: unit)
                    .opacity(isArtworkExpanded ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: isArtworkExpanded)
                if data.track != nil && playerActions != nil {
                    let scale = min(1, max(0.25, unit / 720))
                    MusicBar(data: data, animate: animate, isArtworkExpanded: $isArtworkExpanded,
                             actions: playerActions)
                        .scaleEffect(scale, anchor: .bottom)
                        .frame(width: MusicBar.width * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, unit * 0.045)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .background(DisplayEdgeReader { displayGeometry = $0 })
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .foregroundStyle(Color(white: 0.94))
        .onChange(of: data.track == nil) { _, empty in
            if empty { isArtworkExpanded = false }
        }
    }

    @ViewBuilder
    private func artwork(size: CGSize, unit: CGFloat) -> some View {
        let image = data.look == .monochrome ? MonochromeArtwork.image(for: data.artwork) : data.artwork
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.23))
                    .id(trackIdentity + data.look.rawValue)
                    .transition(.opacity)
            } else {
                RadialGradient(colors: [data.look == .album ? data.palette.primary.opacity(0.5) : Color(white: 0.12), .black],
                               center: .center, startRadius: 0, endRadius: unit * 0.9)
            }
            RadialGradient(colors: [.clear, .black.opacity(0.48)], center: .center,
                           startRadius: unit * 0.15, endRadius: max(size.width, size.height) * 0.65)
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: 0.8), value: trackIdentity)
    }

    private func title(unit: CGFloat) -> some View {
        Text((data.track?.album.isEmpty == false ? data.track?.album : data.track?.title) ?? "HUM")
            .font(.system(size: unit * 0.036, weight: .bold, design: .serif))
            .tracking(unit * 0.002)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .frame(maxWidth: unit * 0.80)
            .shadow(color: .black.opacity(0.8), radius: 8)
    }

    @ViewBuilder
    private func lyrics(size: CGSize, unit: CGFloat) -> some View {
        if !data.lines.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !(animate && data.isPlaying))) { timeline in
                let index = data.lines.activeIndex(at: data.lyricTime(timeline.date))
                ZStack {
                    if let index {
                        LiveLyricEffect(kind: data.effect, line: data.lines[index], palette: .fallback,
                                        fontSize: unit * 0.035, alignment: .center,
                                        isPlaying: animate && data.isPlaying,
                                        previous: index > 0 ? data.lines[index - 1] : nil,
                                        lyricTime: data.lyricTime)
                            .id("\(trackIdentity)-\(index)")
                            .transition(.opacity)
                    } else {
                        Text("Lyrics begin shortly")
                            .font(.system(size: unit * 0.022, design: .serif))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.28), value: index)
                .animation(.easeOut(duration: 0.28), value: trackIdentity)
            }
            .frame(width: size.width * 0.88)
            .shadow(color: .black.opacity(0.65), radius: 6)
            .position(x: size.width * 0.5, y: size.height * 0.55)
        } else {
            VStack(spacing: unit * 0.015) {
                Text(data.track?.title ?? "A little space to listen.")
                    .font(.system(size: unit * 0.037, weight: .regular, design: .serif))
                    .lineLimit(2)
                Text(data.statusMessage ?? (data.track == nil ? "Play something in Spotify or Apple Music" :
                                            data.isPlaying ? "Synced lyrics unavailable for this track" : "Playback paused"))
                    .font(.system(size: unit * 0.018))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)
            .frame(width: size.width * 0.7)
            .shadow(color: .black, radius: 10)
            .position(x: size.width * 0.5, y: size.height * 0.55)
        }
    }

}

/// Vector light refractions: a bowed poster frame and soft crossing beams.
/// No full-screen blur or per-frame image processing.
private struct CinematicLight: View {
    let time: TimeInterval
    let hasArtwork: Bool

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let w = size.width, h = size.height
            let t = time * 0.42
            let frameWidth = min(w * 0.56, h * 0.76)
            let x = (w - frameWidth) / 2
            let top = h * 0.135, bottom = h * 0.94
            let bend = h * 0.018 * sin(t * 0.8)
            var frame = Path()
            frame.move(to: CGPoint(x: x + frameWidth * 0.5, y: top))
            frame.addLine(to: CGPoint(x: x, y: top))
            frame.addCurve(to: CGPoint(x: x, y: bottom),
                           control1: CGPoint(x: x + bend, y: h * 0.38),
                           control2: CGPoint(x: x - bend, y: h * 0.73))
            frame.addLine(to: CGPoint(x: x + frameWidth, y: bottom))
            frame.addCurve(to: CGPoint(x: x + frameWidth, y: top),
                           control1: CGPoint(x: x + frameWidth + bend, y: h * 0.73),
                           control2: CGPoint(x: x + frameWidth - bend, y: h * 0.38))
            frame.addLine(to: CGPoint(x: x + frameWidth * 0.5, y: top))
            if hasArtwork {
                context.stroke(frame, with: .color(.white.opacity(0.42)), lineWidth: max(0.6, h * 0.0018))
            }

            // The broad moving light stays translucent so text remains readable throughout a pass.
            for index in 0..<2 {
                let phase = t + Double(index) * .pi
                let center = CGPoint(x: w * (0.5 + 0.39 * sin(phase * 0.65)), y: h * 0.52)
                var beam = context
                beam.translateBy(x: center.x, y: center.y)
                beam.rotate(by: .radians(0.25 * sin(phase)))
                beam.scaleBy(x: 0.19, y: 1)
                let radius = h * 0.78
                beam.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                          with: .radialGradient(Gradient(colors: [.white.opacity(0.13), .white.opacity(0.035), .clear]),
                                                center: .zero, startRadius: 0, endRadius: radius))
            }

        }
    }
}

private final class CinematicShaderBundle: NSObject {}
