import SwiftUI

/// Lays words out left to right, wrapping into rows, each row aligned per `alignment`.
struct FlowLayout: Layout {
    var alignment: LyricAlignment = .leading
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    struct Cache {
        var sizes: [CGSize] = []
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let rows = rows(maxWidth: proposal.width ?? .infinity, sizes: cache.sizes)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: max(0, proposal.width.map { min($0, width) } ?? width), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, sizes: cache.sizes) {
            let slack = bounds.width - row.width
            var x = bounds.minX + {
                switch alignment {
                case .leading: return 0
                case .center: return slack / 2
                case .trailing: return slack
                }
            }()
            for index in row.indices {
                let size = cache.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (index, size) in sizes.enumerated() {
            let added = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if added > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

extension LyricRenderContext {
    var wordSpacing: CGFloat { fontSize * 0.28 }
    var rowSpacing: CGFloat { fontSize * 0.22 }

    /// Words to lay out; a line without words (e.g. "♪") becomes one pseudo-word.
    var layoutWords: [TimedWord] {
        line.words.isEmpty
            ? [TimedWord(text: line.displayText, start: line.start, end: line.end)]
            : line.words
    }

    func fillForLayoutWord(_ index: Int) -> Double {
        line.words.isEmpty ? progress : fill(ofWord: index)
    }
}
