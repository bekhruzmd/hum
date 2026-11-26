import SwiftUI

/// Each sung word lands as a star with a small label; thin lines link it to the words before,
/// so the line draws a constellation as it's sung. The current word gets a slowly turning
/// sparkle reticle and appears large beside its star. The previous line's constellation stays
/// faintly on the left while the new one grows on the right.
///
/// Stars are drawn in one `Canvas` (no per-word views). Word labels are Canvas symbols,
/// so SwiftUI lays each out once per line instead of resolving text on every frame.
struct ConstellationEffect: LyricEffect {
    func render(_ context: LyricRenderContext) -> some View {
        let words = context.line.words
        let current = context.currentWordIndex.flatMap { words.indices.contains($0) ? $0 : nil }
        VStack(alignment: context.alignment.horizontalAlignment, spacing: context.fontSize * 0.45) {
            Canvas { canvas, size in
                ConstellationRenderer(context: context, size: size).draw(in: &canvas)
            } symbols: {
                ForEach(words.indices, id: \.self) { index in
                    Text(words[index].text)
                        .font(.system(size: context.fontSize * 0.42, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .tag(index)
                }
                if let current {
                    Text(words[current].text)
                        .font(.system(size: context.fontSize * 1.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .tag(ConstellationRenderer.bigWordTag)
                }
            }
            .frame(height: context.fontSize * 8.5)
            Text(context.line.displayText)
                .font(.system(size: context.fontSize * 0.44, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.48))
                .multilineTextAlignment(context.alignment.textAlignment)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: context.alignment.frameAlignment)
    }
}

/// Real astronomical constellation definitions with canonical star coordinates and asterisms.
struct ConstellationDef {
    let name: String
    let anchors: [CGPoint]        // Normalized [0, 1] ordered roughly west-to-east (left-to-right)
    let extraLinks: [(Int, Int)] // Canonical asterism links (closing bowls, crosses, parallelograms)
}

/// Star positions for one line: deterministic per line, mapped to real iconic astronomical
/// constellations (Ursa Major, Cassiopeia, Orion, Cygnus, Crux, Lyra, Leo, Aquila, Taurus, Pegasus),
/// with forward-only left-to-right lyric progression, dynamic vertical peaks/dips, and live continuous
/// zero-G orbital floating drift.
struct ConstellationLayout {
    struct Star {
        let basePoint: CGPoint
        let extraLinks: [Int]
        let phase: Double
        let sizeMultiplier: Double
        let driftSpeedX: Double
        let driftSpeedY: Double
        let driftAmpX: CGFloat
        let driftAmpY: CGFloat
        let phaseX: Double
        let phaseY: Double
    }

    static let catalog: [ConstellationDef] = [
        ConstellationDef(
            name: "Cassiopeia",
            anchors: [
                CGPoint(x: 0.06, y: 0.35),
                CGPoint(x: 0.28, y: 0.82),
                CGPoint(x: 0.50, y: 0.28),
                CGPoint(x: 0.74, y: 0.80),
                CGPoint(x: 0.94, y: 0.40)
            ],
            extraLinks: []
        ),
        ConstellationDef(
            name: "Ursa Major",
            anchors: [
                CGPoint(x: 0.06, y: 0.24), // Alkaid
                CGPoint(x: 0.20, y: 0.15), // Mizar
                CGPoint(x: 0.36, y: 0.32), // Alioth
                CGPoint(x: 0.54, y: 0.48), // Megrez
                CGPoint(x: 0.64, y: 0.88), // Phecda
                CGPoint(x: 0.86, y: 0.85), // Merak
                CGPoint(x: 0.92, y: 0.42)  // Dubhe
            ],
            extraLinks: [(3, 6)] // Megrez to Dubhe closes the Dipper's bowl
        ),
        ConstellationDef(
            name: "Orion",
            anchors: [
                CGPoint(x: 0.12, y: 0.20), // Betelgeuse
                CGPoint(x: 0.24, y: 0.86), // Saiph
                CGPoint(x: 0.38, y: 0.56), // Alnitak
                CGPoint(x: 0.50, y: 0.52), // Alnilam
                CGPoint(x: 0.64, y: 0.48), // Mintaka
                CGPoint(x: 0.80, y: 0.86), // Rigel
                CGPoint(x: 0.90, y: 0.22)  // Bellatrix
            ],
            extraLinks: [(0, 2), (1, 2), (4, 5), (4, 6), (0, 6), (1, 5)]
        ),
        ConstellationDef(
            name: "Cygnus",
            anchors: [
                CGPoint(x: 0.08, y: 0.52), // Albireo (Head)
                CGPoint(x: 0.46, y: 0.16), // Fawaris (Wing up)
                CGPoint(x: 0.52, y: 0.50), // Sadr (Center)
                CGPoint(x: 0.58, y: 0.86), // Gienah (Wing down)
                CGPoint(x: 0.92, y: 0.48)  // Deneb (Tail)
            ],
            extraLinks: [(0, 2), (2, 4)]
        ),
        ConstellationDef(
            name: "Crux",
            anchors: [
                CGPoint(x: 0.12, y: 0.52), // Mimosa
                CGPoint(x: 0.48, y: 0.18), // Gacrux
                CGPoint(x: 0.52, y: 0.84), // Acrux
                CGPoint(x: 0.88, y: 0.48)  // Imai
            ],
            extraLinks: [(1, 2), (0, 3)]
        ),
        ConstellationDef(
            name: "Lyra",
            anchors: [
                CGPoint(x: 0.10, y: 0.20), // Vega
                CGPoint(x: 0.36, y: 0.42),
                CGPoint(x: 0.52, y: 0.82),
                CGPoint(x: 0.80, y: 0.85),
                CGPoint(x: 0.88, y: 0.46)
            ],
            extraLinks: [(1, 4), (2, 3)]
        ),
        ConstellationDef(
            name: "Leo",
            anchors: [
                CGPoint(x: 0.12, y: 0.82), // Regulus
                CGPoint(x: 0.26, y: 0.50), // Algieba
                CGPoint(x: 0.38, y: 0.18), // Adhafera
                CGPoint(x: 0.64, y: 0.36), // Zosma
                CGPoint(x: 0.70, y: 0.76), // Chertan
                CGPoint(x: 0.92, y: 0.52)  // Denebola
            ],
            extraLinks: [(1, 4)]
        ),
        ConstellationDef(
            name: "Aquila",
            anchors: [
                CGPoint(x: 0.10, y: 0.52), // Okab
                CGPoint(x: 0.45, y: 0.78), // Alshain
                CGPoint(x: 0.52, y: 0.46), // Altair
                CGPoint(x: 0.58, y: 0.18), // Tarazed
                CGPoint(x: 0.90, y: 0.48)  // Deneb Okab
            ],
            extraLinks: [(0, 2), (2, 4)]
        ),
        ConstellationDef(
            name: "Taurus",
            anchors: [
                CGPoint(x: 0.08, y: 0.30), // Pleiades
                CGPoint(x: 0.38, y: 0.54), // Ain
                CGPoint(x: 0.54, y: 0.78), // Aldebaran
                CGPoint(x: 0.64, y: 0.46), // Hyades
                CGPoint(x: 0.84, y: 0.72), // Tianguan
                CGPoint(x: 0.92, y: 0.20)  // El-Nath
            ],
            extraLinks: [(1, 3), (3, 5)]
        ),
        ConstellationDef(
            name: "Pegasus",
            anchors: [
                CGPoint(x: 0.10, y: 0.65), // Enif
                CGPoint(x: 0.35, y: 0.25), // Scheat
                CGPoint(x: 0.42, y: 0.75), // Markab
                CGPoint(x: 0.80, y: 0.25), // Alpheratz
                CGPoint(x: 0.90, y: 0.75)  // Algenib
            ],
            extraLinks: [(1, 3), (2, 4)]
        )
    ]

    static let freestyleNames: [String] = [
        "Aurora", "Solaris", "Nebula", "Phoenix", "Cosmos",
        "Pulsar", "Borealis", "Zenith", "Astralis", "Vesper",
        "Voyager", "Nova", "Eclipse", "Hyperion", "Halcyon",
        "Sirius", "Andromeda", "Draco", "Centaurus", "Polaris"
    ]

    /// Procedurally generates a freestyle cosmic constellation with forward-advancing movement,
    /// dynamic ascents/descents, and authentic asterism cross-links.
    static func generateFreestyle(count: Int, seed: UInt64, rng: inout SeededRandom) -> (name: String, points: [CGPoint], links: [[Int]]) {
        let nameIdx = Int((seed / 3) % UInt64(freestyleNames.count))
        let name = freestyleNames[nameIdx]

        if count <= 1 {
            return (name, [CGPoint(x: 0.5, y: 0.5)], [[]])
        }

        // Monotonically increasing X coordinates strictly advancing forward across [0.06, 0.94]
        var rawX: [CGFloat] = []
        let step = 0.88 / CGFloat(count - 1)
        var currentX: CGFloat = 0.06
        for i in 0..<count {
            if i == 0 {
                rawX.append(0.06)
            } else if i == count - 1 {
                rawX.append(0.94)
            } else {
                let jitter = CGFloat(rng.next(in: -0.20...0.20)) * step * 0.4
                currentX = max(currentX + step * 0.35, 0.06 + CGFloat(i) * step + jitter)
                rawX.append(currentX)
            }
        }

        // Diverse vertical motion archetypes: climbing up, plunging down, peaks, valleys, celestial arcs
        let archetype = Int(rng.next(in: 0...4.99))
        var rawY: [CGFloat] = []

        switch archetype {
        case 0:
            // Sinusoidal wave (climbing up, swooping into valleys)
            let freq = Double(rng.next(in: 2.5...5.0))
            let phase = Double(rng.next(in: 0...6.28))
            let amp = CGFloat(rng.next(in: 0.24...0.38))
            for i in 0..<count {
                let t = Double(i) / Double(count - 1)
                let y = 0.5 + amp * CGFloat(sin(t * freq + phase))
                rawY.append(max(0.12, min(0.88, y)))
            }
        case 1:
            // Vault / Celestial Arc (soaring peak or deep celestial cradle)
            let invert = rng.next(in: 0...1) > 0.5
            let peak = CGFloat(rng.next(in: 0.28...0.42)) * (invert ? -1 : 1)
            let tilt = CGFloat(rng.next(in: -0.15...0.15))
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(count - 1)
                let arc = 4 * t * (1 - t) * peak
                let y = 0.5 + arc + (t - 0.5) * tilt
                rawY.append(max(0.12, min(0.88, y)))
            }
        case 2:
            // Ridge & Valley (alternating dynamic ascents and descents)
            let base = CGFloat(rng.next(in: 0.45...0.55))
            let height = CGFloat(rng.next(in: 0.25...0.38))
            for i in 0..<count {
                let sign: CGFloat = (i % 2 == 0) ? -1 : 1
                let noise = CGFloat(rng.next(in: -0.06...0.06))
                let y = base + sign * height + noise
                rawY.append(max(0.12, min(0.88, y)))
            }
        case 3:
            // Stepping stairway with plateaus
            var curY = CGFloat(rng.next(in: 0.2...0.8))
            let dir: CGFloat = curY > 0.5 ? -1 : 1
            for i in 0..<count {
                if i > 0 && rng.next(in: 0...1) > 0.3 {
                    curY += dir * CGFloat(rng.next(in: 0.08...0.22))
                    curY = max(0.15, min(0.85, curY))
                }
                rawY.append(curY)
            }
        default:
            // Bounded organic walk (smooth dynamic up, down, forward)
            var curY: CGFloat = CGFloat(rng.next(in: 0.35...0.65))
            for _ in 0..<count {
                let delta = CGFloat(rng.next(in: -0.28...0.28))
                // Spring force to keep stars within comfortable celestial bounds
                let spring = (0.5 - curY) * 0.4
                curY = max(0.12, min(0.88, curY + delta + spring))
                rawY.append(curY)
            }
        }

        var points: [CGPoint] = []
        for i in 0..<count {
            points.append(CGPoint(x: rawX[i], y: rawY[i]))
        }

        // Procedural asterism cross-links (creating triangles, loops, or cross-ties)
        var links: [[Int]] = Array(repeating: [], count: count)
        if count >= 4 {
            let maxLinks = min(3, count / 3)
            var added = 0
            for i in 2..<count where added < maxLinks {
                let target = i - Int(rng.next(in: 2...min(4, Float(i))))
                if target >= 0 && target != i - 1 && !links[i].contains(target) && rng.next(in: 0...1) > 0.45 {
                    links[i].append(target)
                    added += 1
                }
            }
        }

        return (name, points, links)
    }

    let constellationName: String
    let stars: [Star]

    /// Calculates the live floating point of a star in space at `time`.
    func point(for index: Int, time: Double) -> CGPoint {
        guard stars.indices.contains(index) else { return .zero }
        let star = stars[index]
        let swayX = CGFloat(sin(time * star.driftSpeedX + star.phaseX)) * star.driftAmpX
                  + CGFloat(cos(time * 0.65 * star.driftSpeedX + star.phaseY)) * (star.driftAmpX * 0.35)
        let swayY = CGFloat(cos(time * star.driftSpeedY + star.phaseY)) * star.driftAmpY
                  + CGFloat(sin(time * 0.75 * star.driftSpeedY + star.phaseX)) * (star.driftAmpY * 0.35)
        return CGPoint(x: star.basePoint.x + swayX, y: star.basePoint.y + swayY)
    }

    /// - Parameter rect: the area the stars may occupy.
    init(line: TimedLine, in rect: CGRect) {
        let count = max(1, line.words.count)
        // Hash the line ID along with the text hash so repeating line IDs with different words produce fresh layouts
        var textHasher = Hasher()
        textHasher.combine(line.id)
        textHasher.combine(line.displayText)
        let seed = UInt64(truncatingIfNeeded: textHasher.finalize())
        var rng = SeededRandom(seed: seed)

        // 50% chance of authentic astronomical constellation, 50% chance of procedural freestyle constellation
        let isFreestyle = (seed % 2 != 0)

        let defName: String
        let rawPoints: [CGPoint]
        let links: [[Int]]

        if isFreestyle {
            let (name, pts, extraLinks) = Self.generateFreestyle(count: count, seed: seed, rng: &rng)
            defName = name
            rawPoints = pts
            links = extraLinks
        } else {
            let constIdx = Int((seed / 2) % UInt64(Self.catalog.count))
            let def = Self.catalog[constIdx]
            defName = def.name

            let m = def.anchors.count
            var pts: [CGPoint] = []

            if count <= 1 {
                pts = [CGPoint(x: 0.5, y: 0.5)]
            } else {
                // Sample along the authentic constellation's anchor stars with forward-only progression
                for i in 0..<count {
                    let t = Double(i) / Double(count - 1)
                    let vIdx = t * Double(m - 1)
                    let i0 = Int(vIdx)
                    let i1 = min(m - 1, i0 + 1)
                    let frac = CGFloat(vIdx - Double(i0))
                    let p0 = def.anchors[i0]
                    let p1 = def.anchors[i1]
                    let x = p0.x + (p1.x - p0.x) * frac
                    let y = p0.y + (p1.y - p0.y) * frac
                    // Subtle organic vertical variance per line so repeated constellations breathe uniquely
                    let wobble = CGFloat(rng.next(in: -0.04...0.04))
                    pts.append(CGPoint(x: x, y: max(0.08, min(0.92, y + wobble))))
                }
            }
            rawPoints = pts

            // Map authentic asterism links to the sampled star indices
            var mappedLinks: [[Int]] = Array(repeating: [], count: count)
            for (a0, a1) in def.extraLinks {
                if count == m {
                    if a1 < count { mappedLinks[a1].append(a0) }
                } else if count > 1 {
                    let mapped0 = Int(round(Double(a0) / Double(m - 1) * Double(count - 1)))
                    let mapped1 = Int(round(Double(a1) / Double(m - 1) * Double(count - 1)))
                    if mapped0 != mapped1 && mapped1 < count && !mappedLinks[mapped1].contains(mapped0) {
                        mappedLinks[mapped1].append(mapped0)
                    }
                }
            }
            links = mappedLinks
        }

        self.constellationName = defName

        let safeMarginX = rect.width * 0.05
        let safeMarginY = rect.height * 0.08
        let usableWidth = max(40, rect.width - safeMarginX * 2)
        let usableHeight = max(40, rect.height - safeMarginY * 2)

        let minX = rawPoints.map(\.x).min() ?? 0
        let maxX = rawPoints.map(\.x).max() ?? 1
        let minY = rawPoints.map(\.y).min() ?? 0
        let maxY = rawPoints.map(\.y).max() ?? 1

        let basePoints: [CGPoint]
        if count <= 1 {
            basePoints = [CGPoint(x: rect.midX, y: rect.midY)]
        } else {
            let spanX = max(0.001, maxX - minX)
            let spanY = max(0.001, maxY - minY)

            // Fill 80% to 94% of the usable width and 75% to 88% of the height
            let fillFactorX: CGFloat = min(0.94, max(0.78, 0.70 + CGFloat(count) * 0.035))
            let targetSpanX = usableWidth * fillFactorX
            let targetSpanY = usableHeight * 0.82

            let scaleX = targetSpanX / spanX
            let scaleY = targetSpanY / spanY

            let centerX = (minX + maxX) * 0.5 * scaleX
            let centerY = (minY + maxY) * 0.5 * scaleY
            let offsetX = rect.midX - centerX
            let offsetY = rect.midY - centerY

            basePoints = rawPoints.map { pt in
                CGPoint(x: pt.x * scaleX + offsetX, y: pt.y * scaleY + offsetY)
            }
        }

        var stars: [Star] = []
        for i in 0..<count {
            let phase = Double(rng.next(in: 0...6.28))
            let sizeMul = Double(rng.next(in: 0.8...1.35))
            let driftSpeedX = Double(rng.next(in: 1.0...2.2))
            let driftSpeedY = Double(rng.next(in: 0.8...1.9))
            let driftAmpX = CGFloat(rng.next(in: 6.0...14.0))
            let driftAmpY = CGFloat(rng.next(in: 6.0...14.0))
            let phaseX = Double(rng.next(in: 0...6.28))
            let phaseY = Double(rng.next(in: 0...6.28))

            stars.append(Star(
                basePoint: basePoints[i],
                extraLinks: links[i],
                phase: phase,
                sizeMultiplier: sizeMul,
                driftSpeedX: driftSpeedX,
                driftSpeedY: driftSpeedY,
                driftAmpX: driftAmpX,
                driftAmpY: driftAmpY,
                phaseX: phaseX,
                phaseY: phaseY
            ))
        }
        self.stars = stars
    }
}

struct ConstellationRenderer {
    static let bigWordTag = -1

    let context: LyricRenderContext
    let size: CGSize

    private var font: CGFloat { context.fontSize }
    private var ink: Color { .primary }

    func draw(in canvas: inout GraphicsContext) {
        let starBand = CGRect(
            x: font * 0.6,
            y: font * 0.6,
            width: max(0, size.width - font * 1.2),
            height: size.height * 0.68
        )
        let layout = ConstellationLayout(line: context.line, in: starBand)
        drawConstellationBadge(name: layout.constellationName, in: starBand, canvas: &canvas)
        drawLive(with: layout, in: starBand, canvas: &canvas)
    }

    private func drawConstellationBadge(name: String, in rect: CGRect, canvas: inout GraphicsContext) {
        guard !name.isEmpty && !context.line.words.isEmpty else { return }
        let badge = Text("✦ \(name.uppercased())")
            .font(.system(size: font * 0.32, weight: .semibold, design: .serif))
            .foregroundStyle(ink.opacity(0.32))
        canvas.draw(badge, at: CGPoint(x: rect.maxX - font * 0.2, y: rect.minY - font * 0.05), anchor: .topTrailing)
    }

    // MARK: Lines

    private func drawFinished(_ line: TimedLine, in rect: CGRect, opacity: Double, canvas: inout GraphicsContext) {
        let layout = ConstellationLayout(line: line, in: rect)
        var inner = canvas
        inner.opacity = opacity
        for (index, star) in layout.stars.enumerated() {
            let pt = layout.point(for: index, time: context.time)
            if index > 0 {
                let prevPt = layout.point(for: index - 1, time: context.time)
                link(prevPt, pt, amount: 1, alpha: 0.7, canvas: &inner)
            }
            for extra in star.extraLinks {
                if layout.stars.indices.contains(extra) {
                    let extraPt = layout.point(for: extra, time: context.time)
                    link(extraPt, pt, amount: 1, alpha: 0.35, canvas: &inner)
                }
            }
            dot(at: pt, radius: font * 0.09 * star.sizeMultiplier, alpha: 1, canvas: &inner)
        }
    }

    private func drawLive(with layout: ConstellationLayout, in rect: CGRect, canvas: inout GraphicsContext) {
        let line = context.line
        guard !line.words.isEmpty else {
            // Instrumental "♪": a single pulsing star.
            let pulse = 0.6 + 0.4 * sin(context.time * 3)
            dot(at: CGPoint(x: rect.midX, y: rect.midY), radius: font * 0.12 * pulse, alpha: 0.8, canvas: &canvas)
            return
        }
        let current = context.currentWordIndex

        for (index, star) in layout.stars.enumerated() {
            let appear = appearance(of: index)
            guard appear > 0 else { continue }
            let pt = layout.point(for: index, time: context.time)
            if index > 0 {
                let prevPt = layout.point(for: index - 1, time: context.time)
                link(prevPt, pt, amount: ease(min(1, appear * 1.6)), alpha: 0.75, canvas: &canvas)
            }
            for extra in star.extraLinks where appear > 0.35 {
                if layout.stars.indices.contains(extra) {
                    let extraPt = layout.point(for: extra, time: context.time)
                    link(extraPt, pt, amount: ease((appear - 0.35) / 0.65), alpha: 0.38, canvas: &canvas)
                }
            }
        }
        var labelBounds: [CGRect] = []
        for (index, star) in layout.stars.enumerated() {
            let appear = appearance(of: index)
            guard appear > 0 else { continue }
            let pt = layout.point(for: index, time: context.time)
            let pop = 1 + 0.5 * max(0, 1 - appear * 2.5)
            // Organic micro-twinkle
            let twinkle = 0.92 + 0.16 * sin(context.time * 2.5 + star.phase)
            let radius = font * 0.12 * pop * star.sizeMultiplier * twinkle
            dot(at: pt, radius: radius, alpha: min(1, appear * 2), canvas: &canvas)
            if index != current {
                label(index, at: pt, alpha: min(0.75, appear * 1.5), occupied: &labelBounds, canvas: &canvas)
            }
        }
        if let current, layout.stars.indices.contains(current) {
            let point = layout.point(for: current, time: context.time)
            let appear = appearance(of: current)
            let origin = current > 0 ? layout.point(for: current - 1, time: context.time) : point
            let travel = ease(min(1, appear * 1.8))
            let focus = CGPoint(x: origin.x + (point.x - origin.x) * travel,
                                y: origin.y + (point.y - origin.y) * travel)
            reticle(at: focus, appear: max(0.65, appear), canvas: &canvas)
            bigWord(near: point, appear: appear, canvas: &canvas)
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

    private func label(_ index: Int, at point: CGPoint, alpha: Double, occupied: inout [CGRect], canvas: inout GraphicsContext) {
        guard let symbol = canvas.resolveSymbol(id: index) else { return }
        let bounds = CGRect(x: point.x - symbol.size.width / 2, y: point.y + font * 0.3,
                            width: symbol.size.width, height: symbol.size.height)
        let padded = bounds.insetBy(dx: -font * 0.12, dy: -font * 0.08)
        // The full line remains below the constellation; omit crowded decorative labels.
        guard bounds.minX >= 0, bounds.maxX <= size.width,
              !occupied.contains(where: { $0.intersects(padded) }) else { return }
        occupied.append(padded)
        var layer = canvas
        layer.opacity = alpha
        layer.draw(symbol, at: CGPoint(x: point.x, y: point.y + font * 0.3), anchor: .top)
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

    private func bigWord(near point: CGPoint, appear: Double, canvas: inout GraphicsContext) {
        guard let symbol = canvas.resolveSymbol(id: Self.bigWordTag) else { return }
        let scale = min(1, max(1, size.width - font * 0.4) / max(1, symbol.size.width))
        let measured = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        var origin = CGPoint(x: point.x - font * 0.3, y: point.y + font * 0.55 + CGFloat(1 - ease(appear)) * font * 0.3)
        origin.x = max(font * 0.2, min(origin.x, size.width - measured.width - font * 0.2))
        origin.y = min(origin.y, size.height - measured.height)
        var glow = canvas
        glow.opacity = ease(appear)
        glow.addFilter(.shadow(color: context.palette.highlight.opacity(0.6 * appear), radius: font * 0.4))
        glow.translateBy(x: origin.x, y: origin.y)
        glow.scaleBy(x: scale, y: scale)
        glow.draw(symbol, at: .zero, anchor: .topLeading)
    }
}
