import SwiftUI

/// Each sung word lands as a star with a small label; thin lines link it to the words before,
/// so the line draws a constellation as it's sung. The current word gets a slowly turning
/// sparkle reticle and appears large beside its star. The previous line's constellation stays
/// faintly on the left while the new one grows on the right.
///
/// Everything is drawn in one `Canvas` (no per-word views), so it stays cheap at 60 fps.
struct ConstellationEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        Canvas { canvas, size in
            ConstellationRenderer(context: context, size: size).draw(in: &canvas)
        }
        .frame(height: context.fontSize * 9)
        .frame(maxWidth: .infinity)
    }
}

/// Star positions for one line: deterministic (seeded by line id) so they never jump.
struct ConstellationLayout {
    struct Star {
        let point: CGPoint
        /// Index of an extra, earlier star to link to (makes triangles), if any.
        let extraLink: Int?
    }

    let stars: [Star]

    /// - Parameter rect: the area the stars may occupy.
    init(line: TimedLine, in rect: CGRect) {
        let count = max(1, line.words.count)
        var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: line.id &* 2_654_435_761 &+ 97))
        let step = rect.width / CGFloat(count)
        var stars: [Star] = []
        var y = rect.minY + rect.height * CGFloat(rng.next(in: 0.2...0.8))
        var direction: CGFloat = rng.nextUnit() < 0.5 ? -1 : 1
        for index in 0..<count {
            let jitterX = CGFloat(rng.next(in: -0.28...0.28)) * step
            let x = rect.minX + step * (CGFloat(index) + 0.5) + jitterX
            // A zigzag path: mostly alternating up and down by random amounts, kept in bounds.
            if index > 0 {
                if rng.nextUnit() < 0.75 { direction = -direction }
                y += direction * CGFloat(rng.next(in: 0.25...0.75)) * rect.height
                if y < rect.minY || y > rect.maxY {
                    direction = -direction
                    y = min(rect.maxY, max(rect.minY, y))
                }
            }
            let extra: Int? = index >= 2 && rng.nextUnit() < 0.45 ? index - 2 : nil
            stars.append(Star(point: CGPoint(x: x, y: y), extraLink: extra))
        }
        self.stars = stars
    }
}

private struct ConstellationRenderer {
    let context: LyricRenderContext
    let size: CGSize

    private var font: CGFloat { context.fontSize }
    private var ink: Color { .primary }

    func draw(in canvas: inout GraphicsContext) {
        let starBand = CGRect(
            x: font * 0.8,
            y: font * 1.0,
            width: max(0, size.width - font * 1.6),
            height: size.height * 0.48
        )
        if let previous = context.previous, !previous.words.isEmpty {
            // Old constellation compressed to the left, faint; the new one takes the right.
            let left = CGRect(x: starBand.minX, y: starBand.minY, width: starBand.width * 0.34, height: starBand.height)
            let right = CGRect(x: starBand.minX + starBand.width * 0.4, y: starBand.minY,
                               width: starBand.width * 0.6, height: starBand.height)
            drawFinished(previous, in: left, opacity: 0.28, canvas: &canvas)
            drawLive(in: right, canvas: &canvas)
        } else {
            drawLive(in: starBand, canvas: &canvas)
        }
    }

    // MARK: Lines

    private func drawFinished(_ line: TimedLine, in rect: CGRect, opacity: Double, canvas: inout GraphicsContext) {
        let layout = ConstellationLayout(line: line, in: rect)
        var inner = canvas
        inner.opacity = opacity
        for (index, star) in layout.stars.enumerated() {
            if index > 0 { link(layout.stars[index - 1].point, star.point, amount: 1, alpha: 0.7, canvas: &inner) }
            if let extra = star.extraLink { link(layout.stars[extra].point, star.point, amount: 1, alpha: 0.4, canvas: &inner) }
            dot(at: star.point, radius: font * 0.09, alpha: 1, canvas: &inner)
        }
    }

    private func drawLive(in rect: CGRect, canvas: inout GraphicsContext) {
        let line = context.line
        guard !line.words.isEmpty else {
            // Instrumental "♪": a single pulsing star.
            let pulse = 0.6 + 0.4 * sin(context.time * 3)
            dot(at: CGPoint(x: rect.midX, y: rect.midY), radius: font * 0.12 * pulse, alpha: 0.8, canvas: &canvas)
            return
        }
        let layout = ConstellationLayout(line: line, in: rect)
        let current = context.currentWordIndex

        for (index, star) in layout.stars.enumerated() {
            let appear = appearance(of: index)
            guard appear > 0 else { continue }
            if index > 0 {
                link(layout.stars[index - 1].point, star.point, amount: ease(min(1, appear * 1.6)), alpha: 0.75, canvas: &canvas)
            }
            if let extra = star.extraLink, appear > 0.4 {
                link(layout.stars[extra].point, star.point, amount: ease((appear - 0.4) / 0.6), alpha: 0.4, canvas: &canvas)
            }
        }
        for (index, star) in layout.stars.enumerated() {
            let appear = appearance(of: index)
            guard appear > 0 else { continue }
            let pop = 1 + 0.6 * max(0, 1 - appear * 2.5)
            dot(at: star.point, radius: font * 0.13 * pop, alpha: min(1, appear * 2), canvas: &canvas)
            if index != current {
                label(line.words[index].text, at: star.point, alpha: min(0.75, appear * 1.5), canvas: &canvas)
            }
        }
        if let current, layout.stars.indices.contains(current) {
            let point = layout.stars[current].point
            let appear = appearance(of: current)
            reticle(at: point, appear: appear, canvas: &canvas)
            bigWord(line.words[current].text, near: point, appear: appear, canvas: &canvas)
        }
    }

    /// 0…1 over the first 0.35 s of a word.
    private func appearance(of index: Int) -> Double {
        let start = context.line.words[index].start
        return min(1, max(0, (context.time - start) / 0.35))
    }

    private func ease(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return 1 - pow(1 - x, 3)
    }

    // MARK: Primitives

    private func link(_ a: CGPoint, _ b: CGPoint, amount: Double, alpha: Double, canvas: inout GraphicsContext) {
        guard amount > 0 else { return }
        let end = CGPoint(x: a.x + (b.x - a.x) * amount, y: a.y + (b.y - a.y) * amount)
        var path = Path()
        path.move(to: a)
        path.addLine(to: end)
        canvas.stroke(path, with: .color(ink.opacity(alpha)), lineWidth: max(0.75, font * 0.045))
    }

    private func dot(at point: CGPoint, radius: CGFloat, alpha: Double, canvas: inout GraphicsContext) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        canvas.fill(Path(ellipseIn: rect.insetBy(dx: -radius * 1.5, dy: -radius * 1.5)),
                    with: .radialGradient(Gradient(colors: [ink.opacity(0.35 * alpha), .clear]),
                                          center: point, startRadius: 0, endRadius: radius * 2.5))
        canvas.fill(Path(ellipseIn: rect), with: .color(ink.opacity(alpha)))
    }

    private func label(_ text: String, at point: CGPoint, alpha: Double, canvas: inout GraphicsContext) {
        let resolved = canvas.resolve(
            Text(text).font(.system(size: font * 0.42, weight: .medium, design: .rounded)).foregroundColor(ink.opacity(alpha))
        )
        canvas.draw(resolved, at: CGPoint(x: point.x, y: point.y + font * 0.3), anchor: .top)
    }

    /// Thin ring, crosshair and a slowly turning four-point sparkle.
    private func reticle(at point: CGPoint, appear: Double, canvas: inout GraphicsContext) {
        let scale = 0.6 + 0.4 * ease(appear)
        let radius = font * 0.7 * scale
        let lineWidth = max(0.75, font * 0.05)
        canvas.stroke(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                      with: .color(ink.opacity(0.9 * appear)), lineWidth: lineWidth)
        var cross = Path()
        let reach = radius * 1.5
        cross.move(to: CGPoint(x: point.x - reach, y: point.y))
        cross.addLine(to: CGPoint(x: point.x + reach, y: point.y))
        cross.move(to: CGPoint(x: point.x, y: point.y - reach))
        cross.addLine(to: CGPoint(x: point.x, y: point.y + reach))
        canvas.stroke(cross, with: .color(ink.opacity(0.55 * appear)), lineWidth: lineWidth * 0.7)

        var sparkle = canvas
        sparkle.translateBy(x: point.x, y: point.y)
        sparkle.rotate(by: .radians(context.time * 0.8))
        sparkle.fill(Self.sparklePath(radius: radius * 0.75), with: .color(ink.opacity(appear)))
    }

    private static func sparklePath(radius: CGFloat) -> Path {
        var path = Path()
        let inner = radius * 0.18
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let r = i.isMultiple(of: 2) ? radius : inner
            let p = CGPoint(x: CGFloat(cos(angle)) * r, y: CGFloat(sin(angle)) * r)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    private func bigWord(_ text: String, near point: CGPoint, appear: Double, canvas: inout GraphicsContext) {
        let resolved = canvas.resolve(
            Text(text)
                .font(.system(size: font * 1.5, weight: .heavy, design: .rounded))
                .foregroundColor(ink.opacity(ease(appear)))
        )
        let measured = resolved.measure(in: size)
        var origin = CGPoint(x: point.x - font * 0.3, y: point.y + font * 0.55 + CGFloat(1 - ease(appear)) * font * 0.3)
        origin.x = min(max(font * 0.2, origin.x), size.width - measured.width - font * 0.2)
        origin.y = min(origin.y, size.height - measured.height)
        var glow = canvas
        glow.addFilter(.shadow(color: context.palette.highlight.opacity(0.6 * appear), radius: font * 0.4))
        glow.draw(resolved, at: origin, anchor: .topLeading)
    }
}
