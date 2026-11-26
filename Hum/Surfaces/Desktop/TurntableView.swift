import SwiftUI

/// Hum's turntable: a graphite plinth, a strobe-dotted platter spinning at 33⅓ rpm with the
/// album cover as the record label, a static light sheen, and a tonearm that swings onto the
/// record on play, tracks inward over the song, and swings back to its rest on pause.
///
/// The record angle is derived from the playback position, so it stops exactly when the music does.
struct TurntableView: View {
    let state: PlaybackState?
    let artwork: NSImage?
    let palette: AlbumPalette
    let animate: Bool

    /// 33⅓ rpm in degrees per second.
    static let degreesPerSecond = 33.333_333 * 360 / 60
    static let aspect: CGFloat = 1.32

    var body: some View {
        GeometryReader { proxy in
            let h = min(proxy.size.height, proxy.size.width / Self.aspect)
            let w = h * Self.aspect
            ZStack(alignment: .topLeading) {
                plinth(width: w, height: h)
                platterAssembly(height: h)
                    .position(x: h * 0.54, y: h * 0.5)
                Tonearm(height: h, angle: armAngle, palette: palette)
                    .frame(width: w, height: h)
                    .animation(.easeInOut(duration: 1.4), value: isPlaying)
                speedLight(height: h)
                    .position(x: w * 0.9, y: h * 0.86)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.map { "Turntable playing \($0.track.title)" } ?? "Turntable")
    }

    private var isPlaying: Bool { state?.isPlaying ?? false }

    private var armAngle: Angle {
        guard let state, state.isPlaying else { return .degrees(0) }
        let progress = state.track.duration > 0 ? state.position / state.track.duration : 0
        return .degrees(24 + 14 * min(1, max(0, progress)))
    }

    // MARK: Parts

    private func plinth(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.06, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.17), Color(white: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: height * 0.06, style: .continuous)
                    .fill(palette.secondary.opacity(0.14))
            }
            .overlay {
                RoundedRectangle(cornerRadius: height * 0.06, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                        lineWidth: max(1, height * 0.004)
                    )
            }
            .shadow(color: .black.opacity(0.45), radius: height * 0.05, y: height * 0.03)
            .frame(width: width, height: height)
    }

    private func platterAssembly(height h: CGFloat) -> some View {
        let platter = h * 0.86
        return ZStack {
            // Platter rim with strobe dots.
            Circle()
                .fill(AngularGradient(
                    colors: [Color(white: 0.55), Color(white: 0.3), Color(white: 0.62), Color(white: 0.28), Color(white: 0.55)],
                    center: .center
                ))
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !(animate && isPlaying))) { timeline in
                let angle = recordAngle(at: timeline.date)
                ZStack {
                    StrobeDots(count: 60, dotSize: h * 0.008)
                        .fill(Color(white: 0.12))
                        .frame(width: platter * 0.975, height: platter * 0.975)
                    record(diameter: platter * 0.93)
                }
                .rotationEffect(.degrees(angle))
            }
            // Fixed sheen: the light doesn't rotate with the record.
            Circle()
                .fill(AngularGradient(
                    colors: [.clear, .white.opacity(0.07), .clear, .clear, .white.opacity(0.05), .clear, .clear],
                    center: .center,
                    angle: .degrees(-35)
                ))
                .frame(width: platter * 0.93, height: platter * 0.93)
                .allowsHitTesting(false)
            // Spindle.
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.95), Color(white: 0.45)], center: .topLeading, startRadius: 0, endRadius: h * 0.02))
                .frame(width: h * 0.022, height: h * 0.022)
        }
        .frame(width: platter, height: platter)
    }

    private func record(diameter: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.04))
            Grooves(rings: 22)
                .stroke(.white.opacity(0.045), lineWidth: max(0.5, diameter * 0.0015))
                .padding(diameter * 0.03)
            Circle()
                .strokeBorder(.white.opacity(0.08), lineWidth: max(0.5, diameter * 0.003))
                .padding(diameter * 0.03)
            label(diameter: diameter * 0.36)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func label(diameter: CGFloat) -> some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [palette.primary, palette.accent], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: diameter * 0.02))
    }

    private func speedLight(height h: CGFloat) -> some View {
        HStack(spacing: h * 0.015) {
            Circle()
                .fill(isPlaying ? palette.highlight : Color(white: 0.25))
                .frame(width: h * 0.018, height: h * 0.018)
                .shadow(color: isPlaying ? palette.highlight : .clear, radius: h * 0.012)
            Text("33")
                .font(.system(size: h * 0.028, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .animation(.easeInOut(duration: 0.6), value: isPlaying)
    }

    private func recordAngle(at date: Date) -> Double {
        guard let state else { return 0 }
        return (state.interpolatedPosition(at: date) * Self.degreesPerSecond).truncatingRemainder(dividingBy: 360)
    }
}

/// Concentric groove rings.
private struct Grooves: Shape {
    let rings: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let maxRadius = min(rect.width, rect.height) / 2
        for i in 0..<rings {
            let radius = maxRadius * (0.42 + 0.58 * CGFloat(i) / CGFloat(max(1, rings - 1)))
            path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

/// Small dots around the platter rim; they make the spin visible.
private struct StrobeDots: Shape {
    let count: Int
    let dotSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2 - dotSize
        for i in 0..<count {
            let angle = Double(i) / Double(count) * 2 * .pi
            let center = CGPoint(x: rect.midX + radius * cos(angle), y: rect.midY + radius * sin(angle))
            path.addEllipse(in: CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize))
        }
        return path
    }
}

/// The tonearm, drawn in plinth coordinates and rotated about its pivot.
private struct Tonearm: View {
    let height: CGFloat
    let angle: Angle
    let palette: AlbumPalette

    var body: some View {
        let h = height
        let pivot = CGPoint(x: h * 1.08, y: h * 0.18)
        let length = h * 0.6
        GeometryReader { proxy in
            let anchor = UnitPoint(x: pivot.x / proxy.size.width, y: pivot.y / proxy.size.height)
            ZStack(alignment: .topLeading) {
                // Arm rest post.
                Capsule()
                    .fill(Color(white: 0.3))
                    .frame(width: h * 0.034, height: h * 0.05)
                    .position(x: pivot.x, y: pivot.y + length * 0.78)

                ZStack(alignment: .topLeading) {
                    // Counterweight behind the pivot.
                    RoundedRectangle(cornerRadius: h * 0.012)
                        .fill(LinearGradient(colors: [Color(white: 0.7), Color(white: 0.35)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: h * 0.06, height: h * 0.08)
                        .position(x: pivot.x, y: pivot.y - h * 0.07)
                    // Arm tube.
                    Capsule()
                        .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.5)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: h * 0.016, height: length)
                        .position(x: pivot.x, y: pivot.y + length / 2)
                    // Headshell, angled slightly inward, with a colored finger lift.
                    RoundedRectangle(cornerRadius: h * 0.008)
                        .fill(Color(white: 0.22))
                        .frame(width: h * 0.045, height: h * 0.075)
                        .rotationEffect(.degrees(18))
                        .position(x: pivot.x - h * 0.008, y: pivot.y + length + h * 0.02)
                    Capsule()
                        .fill(palette.highlight)
                        .frame(width: h * 0.028, height: h * 0.008)
                        .position(x: pivot.x + h * 0.022, y: pivot.y + length + h * 0.005)
                }
                .rotationEffect(angle, anchor: anchor)
                .shadow(color: .black.opacity(0.5), radius: h * 0.01, x: h * 0.008, y: h * 0.012)

                // Pivot base sits on top.
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.6), Color(white: 0.2)], center: .topLeading, startRadius: 0, endRadius: h * 0.07))
                    .frame(width: h * 0.11, height: h * 0.11)
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .position(pivot)
            }
        }
    }
}
