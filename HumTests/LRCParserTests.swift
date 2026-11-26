import XCTest
@testable import Hum

final class LRCParserTests: XCTestCase {
    func testParsesDifferentTimestampPrecisions() {
        let lrc = """
        [00:05]No fraction
        [00:12.34]Two digit fraction
        [01:02.345]Three digit fraction
        """

        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 3)

        XCTAssertEqual(lines[0].time, 5.0, accuracy: 0.0001)
        XCTAssertEqual(lines[0].text, "No fraction")

        XCTAssertEqual(lines[1].time, 12.34, accuracy: 0.0001)
        XCTAssertEqual(lines[1].text, "Two digit fraction")

        XCTAssertEqual(lines[2].time, 62.345, accuracy: 0.0001)
        XCTAssertEqual(lines[2].text, "Three digit fraction")
    }

    func testIgnoresMetadataTags() {
        let lrc = """
        [ar:Artist Name]
        [ti:Song Title]
        [al:Album Name]
        [by:LRC Maker]
        [length:03:20]
        [00:10.00]First real line
        """

        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].time, 10.0, accuracy: 0.0001)
        XCTAssertEqual(lines[0].text, "First real line")
    }

    func testSupportsMultipleTimestampsPerLineAndSortsByTime() {
        let lrc = """
        [00:30.00]Verse one
        [00:15.50][01:05.25]Chorus line
        """

        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 3)

        XCTAssertEqual(lines[0].time, 15.50, accuracy: 0.0001)
        XCTAssertEqual(lines[0].text, "Chorus line")

        XCTAssertEqual(lines[1].time, 30.00, accuracy: 0.0001)
        XCTAssertEqual(lines[1].text, "Verse one")

        XCTAssertEqual(lines[2].time, 65.25, accuracy: 0.0001)
        XCTAssertEqual(lines[2].text, "Chorus line")
    }

    func testActiveLineIndexLookup() {
        let lines = LRCParser.parse("""
        [00:10.00]Line 1
        [00:20.00]Line 2
        [00:30.00]Line 3
        """)

        XCTAssertNil(LRCParser.activeLineIndex(in: lines, at: 5.0))
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 10.0), 0)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 19.9), 0)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 25.0), 1)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 45.0), 2)
    }
}

final class EnhancedLRCParserTests: XCTestCase {
    func testParsesWordTagsAndEndTime() throws {
        let lines = LRCParser.parse("[00:10.00]<00:10.00>Hello <00:10.50>big <00:11.20>world<00:12.00>")
        let line = try XCTUnwrap(lines.first)
        XCTAssertEqual(line.text, "Hello big world")
        XCTAssertEqual(line.words.map(\.text), ["Hello ", "big ", "world"])
        XCTAssertEqual(line.words.map(\.time), [10.0, 10.5, 11.2])
        XCTAssertEqual(try XCTUnwrap(line.endTime), 12.0, accuracy: 0.0001)
    }

    func testPlainLinesHaveNoWords() throws {
        let line = try XCTUnwrap(LRCParser.parse("[00:01.00]Just text").first)
        XCTAssertTrue(line.words.isEmpty)
        XCTAssertNil(line.endTime)
    }

    func testOffsetTagShiftsEarlier() throws {
        let lines = LRCParser.parse("""
        [offset:+500]
        [00:10.00]Line
        """)
        XCTAssertEqual(try XCTUnwrap(lines.first).time, 9.5, accuracy: 0.0001)
    }

    func testBracketsInsideTextAreKept() throws {
        let line = try XCTUnwrap(LRCParser.parse("[00:05.00][Chorus] la la").first)
        XCTAssertEqual(line.text, "[Chorus] la la")
    }

    func testRejectsBadTimestamps() {
        XCTAssertNil(LRCParser.parseTimestamp("aa:bb"))
        XCTAssertNil(LRCParser.parseTimestamp("01:75"))
        XCTAssertNil(LRCParser.parseTimestamp("01:05.1234"))
        XCTAssertEqual(LRCParser.parseTimestamp("01:05:50") ?? 0, 65.5, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("100:00") ?? 0, 6000, accuracy: 0.0001)
    }

    func testEmptyLinesAndActiveIndexBinarySearch() {
        let lines = LRCParser.parse((0..<100).map { String(format: "[%02d:%02d.00]L%d", $0 / 60, $0 % 60, $0) }.joined(separator: "\n"))
        XCTAssertEqual(lines.count, 100)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 42.5), 42)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 1000), 99)
        XCTAssertNil(LRCParser.activeLineIndex(in: [], at: 3))
    }
}
