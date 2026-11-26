import Foundation

/// Parses LRC and Enhanced LRC.
///
/// Supports `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss.xxx]` (also `:` as fraction separator), several
/// timestamps per line, Enhanced LRC word tags `<mm:ss.xx>`, and the `[offset:±ms]` tag.
/// Other metadata tags (`[ar:]`, `[ti:]`, …) and untimed lines are ignored.
enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        var offset: TimeInterval = 0
        var parsed: [(time: TimeInterval, text: String, words: [LyricWord], end: TimeInterval?)] = []

        for rawLine in lrc.components(separatedBy: .newlines) {
            var rest = Substring(rawLine).drop { $0.isWhitespace }
            var times: [TimeInterval] = []

            // Consume leading [tag] groups.
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let time = parseTimestamp(tag) {
                    times.append(time)
                } else if times.isEmpty, let value = metadataValue(tag, key: "offset") {
                    // LRC spec: positive offset (ms) makes lyrics appear sooner.
                    offset = (Double(value) ?? 0) / 1000.0
                } else {
                    break
                }
                rest = rest[rest.index(after: close)...]
            }
            guard !times.isEmpty else { continue }

            let (text, words, end) = parseWords(rest)
            for time in times {
                parsed.append((time, text, words, end))
            }
        }

        return parsed
            .sorted { $0.time < $1.time }
            .enumerated()
            .map { index, item in
                LyricLine(
                    id: index,
                    time: max(0, item.time - offset),
                    text: item.text,
                    words: item.words.map { LyricWord(time: max(0, $0.time - offset), text: $0.text) },
                    endTime: item.end.map { max(0, $0 - offset) }
                )
            }
    }

    /// Index of the line active at `position`, or nil before the first line. Binary search.
    static func activeLineIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
        var low = 0, high = lines.count - 1, result: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    // MARK: Helpers

    /// Parses `mm:ss`, `mm:ss.x…`, or `mm:ss:xx`. Returns seconds.
    static func parseTimestamp<S: StringProtocol>(_ tag: S) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard
            (1...3).contains(parts[0].count), parts[0].allSatisfy(\.isNumber),
            let minutes = Double(parts[0])
        else { return nil }

        var secondsPart = parts[1]
        var fractionPart: Substring?
        if parts.count == 3 {
            fractionPart = Substring(parts[2])
        } else if let dot = secondsPart.firstIndex(of: ".") {
            fractionPart = Substring(secondsPart[secondsPart.index(after: dot)...])
            secondsPart = secondsPart[..<dot]
        }
        guard
            secondsPart.count == 2, secondsPart.allSatisfy(\.isNumber),
            let seconds = Double(secondsPart), seconds < 60
        else { return nil }

        var fraction: Double = 0
        if let fractionPart {
            guard (1...3).contains(fractionPart.count), fractionPart.allSatisfy(\.isNumber),
                  let value = Double(fractionPart) else { return nil }
            fraction = value / pow(10, Double(fractionPart.count))
        }
        return minutes * 60 + seconds + fraction
    }

    private static func metadataValue(_ tag: Substring, key: String) -> Substring? {
        guard let colon = tag.firstIndex(of: ":") else { return nil }
        guard tag[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == key else { return nil }
        return Substring(tag[tag.index(after: colon)...].trimmingCharacters(in: .whitespaces))
    }

    /// Splits Enhanced LRC `<mm:ss.xx>word` runs. Text without word tags returns no words.
    /// A trailing tag with no text after it (`…word <01:02.30>`) becomes the line's end time.
    private static func parseWords(_ body: Substring) -> (String, [LyricWord], TimeInterval?) {
        var words: [LyricWord] = []
        var plain = ""
        var tagTime: TimeInterval?
        var run = ""
        var index = body.startIndex

        func flush() {
            if let tagTime, !run.trimmingCharacters(in: .whitespaces).isEmpty {
                words.append(LyricWord(time: tagTime, text: run))
            }
            run = ""
        }

        while index < body.endIndex {
            if body[index] == "<",
               let close = body[index...].firstIndex(of: ">"),
               let time = parseTimestamp(body[body.index(after: index)..<close]) {
                flush()
                tagTime = time
                index = body.index(after: close)
                continue
            }
            run.append(body[index])
            plain.append(body[index])
            index = body.index(after: index)
        }
        let endsWithBareTag = run.trimmingCharacters(in: .whitespaces).isEmpty
        flush()

        let text = plain.trimmingCharacters(in: .whitespaces)
        guard let first = words.first, let last = words.last else { return (text, [], nil) }
        words[0] = LyricWord(time: first.time, text: String(first.text.drop { $0.isWhitespace }))
        let lastIndex = words.count - 1
        words[lastIndex] = LyricWord(
            time: last.time,
            text: words[lastIndex].text.trimmingCharacters(in: .whitespaces)
        )
        return (text, words, endsWithBareTag ? tagTime : nil)
    }
}
