import XCTest
@testable import Hum

final class NetEaseParserTests: XCTestCase {
    func testParsesYRCWordByWordLyrics() {
        let sampleYRC = """
        {"t":0,"c":[{"tx":"作曲: "},{"tx":"Frank Ocean"}]}
        [3870,660](3870,180,0)Round (4050,120,0)the (4170,360,0)city
        [4530,2250](4530,270,0)Round (4800,90,0)the (4890,540,0)clock
        [6780,2910](6780,720,0)Everybody (7500,390,0)needs (7890,1170,0)you
        """

        let lines = NetEaseParser.parseYRC(sampleYRC)
        XCTAssertEqual(lines.count, 3)

        // Line 1: [3870, 660] => 3.87s
        XCTAssertEqual(lines[0].time, 3.87, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Round the city")
        XCTAssertEqual(lines[0].words.count, 3)
        XCTAssertEqual(lines[0].words[0].text, "Round ")
        XCTAssertEqual(lines[0].words[0].time, 3.87, accuracy: 0.001)
        XCTAssertEqual(lines[0].words[1].text, "the ")
        XCTAssertEqual(lines[0].words[1].time, 4.05, accuracy: 0.001)
        XCTAssertEqual(lines[0].words[2].text, "city")
        XCTAssertEqual(lines[0].words[2].time, 4.17, accuracy: 0.001)

        // Line 2: [4530, 2250] => 4.53s
        XCTAssertEqual(lines[1].time, 4.53, accuracy: 0.001)
        XCTAssertEqual(lines[1].text, "Round the clock")

        // Line 3: [6780, 2910] => 6.78s
        XCTAssertEqual(lines[2].time, 6.78, accuracy: 0.001)
        XCTAssertEqual(lines[2].text, "Everybody needs you")
    }

    func testHandlesCyrillicRussianYRCWords() {
        let russianYRC = """
        [10500,4200](10500,600,0)Тёплое (11100,500,0)место(11600,0,0), (11600,300,0)но (11900,400,0)улицы (12300,500,0)ждут
        """
        let lines = NetEaseParser.parseYRC(russianYRC)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].time, 10.5, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Тёплое место, но улицы ждут")
        XCTAssertGreaterThanOrEqual(lines[0].words.count, 5)
    }
}
