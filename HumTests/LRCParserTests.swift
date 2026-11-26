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
