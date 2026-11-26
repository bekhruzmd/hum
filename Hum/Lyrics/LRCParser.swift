import Foundation

enum LRCParser {
    private static let timestampPattern = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]"#
    )

    static func parse(_ lrc: String) -> [LyricLine] {
        var parsed: [(time: TimeInterval, text: String)] = []

        let lines = lrc.components(separatedBy: .newlines)
        for rawLine in lines {
            let nsRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = timestampPattern.matches(in: rawLine, range: nsRange)
            guard !matches.isEmpty else {
                // Ignores metadata tags like [ar:], [ti:], [al:], etc., and plain non-timestamped lines.
                continue
            }

            // Extract lyric text after removing all timestamp tags from the line.
            let textWithoutTags = timestampPattern.stringByReplacingMatches(
                in: rawLine,
                range: nsRange,
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                guard let time = parseTimestamp(match: match, in: rawLine) else { continue }
                parsed.append((time: time, text: textWithoutTags))
            }
        }

        parsed.sort { $0.time < $1.time }

        return parsed.enumerated().map { index, item in
            LyricLine(id: index, time: item.time, text: item.text)
        }
    }

    /// Returns the index of the active lyric line for a given playback position.
    static func activeLineIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var activeIndex: Int?
        for (index, line) in lines.enumerated() {
            if line.time <= position {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }

    private static func parseTimestamp(match: NSTextCheckingResult, in line: String) -> TimeInterval? {
        guard
            let minRange = Range(match.range(at: 1), in: line),
            let secRange = Range(match.range(at: 2), in: line),
            let minutes = Double(line[minRange]),
            let seconds = Double(line[secRange])
        else {
            return nil
        }

        var fraction: Double = 0
        if match.range(at: 3).location != NSNotFound,
           let fracRange = Range(match.range(at: 3), in: line) {
            let fracString = String(line[fracRange])
            if let fracValue = Double(fracString) {
                let divisor = pow(10.0, Double(fracString.count))
                fraction = fracValue / divisor
            }
        }

        return (minutes * 60.0) + seconds + fraction
    }
}
