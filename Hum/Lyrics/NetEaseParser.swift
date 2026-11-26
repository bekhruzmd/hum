import Foundation

/// Parses NetEase YRC (syllable-by-syllable / word-by-word) and LRC formats into `[LyricLine]`.
///
/// YRC line format:
/// `[lineStartTimeMs,lineDurationMs](wordStartMs,wordDurationMs,0)Word (nextStartMs,nextDurationMs,0)NextWord`
enum NetEaseParser {
    static func parseYRC(_ yrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in yrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Ignore metadata json header lines
            if trimmed.hasPrefix("{") { continue }

            // Must start with [startTime,duration]
            guard trimmed.hasPrefix("["), let closingBracket = trimmed.firstIndex(of: "]") else { continue }
            let lineHeader = trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket]
            let lineHeaderParts = lineHeader.split(separator: ",")
            guard let lineStartMs = Double(lineHeaderParts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let lineDurationMs = lineHeaderParts.count > 1 ? (Double(lineHeaderParts[1].trimmingCharacters(in: .whitespaces)) ?? 0) : 0

            let lineStartTime = lineStartMs / 1000.0
            let lineEndTime = (lineStartMs + lineDurationMs) / 1000.0

            let body = trimmed[trimmed.index(after: closingBracket)...]
            var words: [LyricWord] = []
            var fullText = ""

            // Parse (wordStartMs,wordDurationMs,flag)WordText
            var scanner = Substring(body)
            while let openParen = scanner.firstIndex(of: "(") {
                guard let closeParen = scanner[openParen...].firstIndex(of: ")") else { break }
                let wordHeader = scanner[scanner.index(after: openParen)..<closeParen]
                let wordHeaderParts = wordHeader.split(separator: ",")
                let wordStartMs = Double(wordHeaderParts[0].trimmingCharacters(in: .whitespaces)) ?? lineStartMs
                let wordStartTime = wordStartMs / 1000.0

                let afterClose = scanner.index(after: closeParen)
                let textEnd: String.Index
                if let nextOpen = scanner[afterClose...].firstIndex(of: "(") {
                    textEnd = nextOpen
                } else {
                    textEnd = scanner.endIndex
                }
                let wordText = String(scanner[afterClose..<textEnd])
                if !wordText.isEmpty {
                    words.append(LyricWord(time: wordStartTime, text: wordText))
                    fullText += wordText
                }
                scanner = scanner[textEnd...]
            }

            let text = fullText.trimmingCharacters(in: .whitespaces)
            // Filter out empty lines or author credit headers that have 0 ms timing
            if !text.isEmpty {
                lines.append(LyricLine(
                    id: lines.count,
                    time: lineStartTime,
                    text: text,
                    words: words,
                    endTime: lineEndTime > lineStartTime ? lineEndTime : nil
                ))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}
