import Foundation

struct TimedWord: Equatable, Sendable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
}

/// A lyric line with a start, an end and per-word timings (real or estimated).
struct TimedLine: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let words: [TimedWord]
    /// False when timings came from Enhanced LRC tags.
    let isEstimated: Bool

    var displayText: String { text.isEmpty ? "♪" : text }

    /// 0…1 progress across the whole line.
    func progress(at time: TimeInterval) -> Double {
        guard end > start else { return time >= start ? 1 : 0 }
        return min(1, max(0, (time - start) / (end - start)))
    }

    /// 0…1 fill of word `index` at `time`.
    func fill(ofWord index: Int, at time: TimeInterval) -> Double {
        guard words.indices.contains(index) else { return 0 }
        let word = words[index]
        guard word.end > word.start else { return time >= word.start ? 1 : 0 }
        return min(1, max(0, (time - word.start) / (word.end - word.start)))
    }

    /// Index of the word being sung (or last sung) at `time`, nil before the first word.
    func currentWordIndex(at time: TimeInterval) -> Int? {
        words.lastIndex { $0.start <= time }
    }
}

/// Produces word timings. Uses Enhanced LRC times when present; otherwise spreads the line's
/// duration across its words weighted by character count, with a short pause after punctuation.
enum WordTimingEstimator {
    /// Pause after punctuation, in "character" units of the weighting.
    static let punctuationPause = 3.0
    /// Seconds per character used to cap how long a line can take when the next line is far away.
    static let secondsPerCharacter = 0.16
    static let minimumLineCap = 1.2
    private static let pausingPunctuation: Set<Character> = [",", ".", ";", ":", "!", "?", "…", "—", "-", "、", "。", "，"]

    static func timedLines(from lines: [LyricLine], trackDuration: TimeInterval) -> [TimedLine] {
        lines.enumerated().map { index, line in
            let nextStart = index + 1 < lines.count
                ? lines[index + 1].time
                : (trackDuration > line.time ? trackDuration : line.time + 6)
            return timedLine(for: line, nextStart: nextStart)
        }
    }

    static func timedLine(for line: LyricLine, nextStart: TimeInterval) -> TimedLine {
        let available = max(0, nextStart - line.time)

        if !line.words.isEmpty {
            let lastEnd = line.endTime
                ?? min(nextStart, (line.words.last?.time ?? line.time) + cap(for: line.words.last?.text ?? ""))
            let words = line.words.enumerated().map { index, word in
                let end = index + 1 < line.words.count ? line.words[index + 1].time : max(word.time, lastEnd)
                return TimedWord(text: word.text.trimmingCharacters(in: .whitespaces), start: word.time, end: end)
            }
            return TimedLine(
                id: line.id, text: line.text, start: line.time,
                end: max(line.time, lastEnd), words: words, isEstimated: false
            )
        }

        let duration = min(available, cap(for: line.text))
        let end = line.time + duration
        return TimedLine(
            id: line.id, text: line.text, start: line.time, end: end,
            words: estimate(text: line.text, start: line.time, end: end), isEstimated: true
        )
    }

    static func estimate(text: String, start: TimeInterval, end: TimeInterval) -> [TimedWord] {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty, end > start else {
            return tokens.map { TimedWord(text: $0, start: start, end: start) }
        }

        let weights = tokens.map { token -> (sung: Double, pause: Double) in
            let letters = Double(max(1, token.filter { $0.isLetter || $0.isNumber }.count))
            let pause = token.last.map(pausingPunctuation.contains) == true ? punctuationPause : 0
            return (letters, pause)
        }
        // The final word's pause is not followed by another word, so don't reserve time for it.
        let total = weights.enumerated().reduce(0.0) { sum, item in
            sum + item.element.sung + (item.offset == weights.count - 1 ? 0 : item.element.pause)
        }
        let unit = (end - start) / total

        var cursor = start
        return zip(tokens, weights).map { token, weight in
            let wordEnd = cursor + weight.sung * unit
            defer { cursor = wordEnd + weight.pause * unit }
            return TimedWord(text: token, start: cursor, end: min(end, wordEnd))
        }
    }

    private static func cap(for text: String) -> TimeInterval {
        max(minimumLineCap, Double(text.count) * secondsPerCharacter + 0.6)
    }
}

extension Array where Element == TimedLine {
    /// Index of the line active at `time` (binary search), nil before the first line.
    func activeIndex(at time: TimeInterval) -> Int? {
        var low = 0, high = count - 1, result: Int?
        while low <= high {
            let mid = (low + high) / 2
            if self[mid].start <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }
}
