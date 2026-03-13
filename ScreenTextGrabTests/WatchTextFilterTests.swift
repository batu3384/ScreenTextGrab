import XCTest
@testable import ScreenTextGrab

final class WatchTextFilterTests: XCTestCase {
    func testWholeResultReturnsTrimmedText() {
        let configuration = WatchConfiguration(copyBehavior: .wholeResult, regexFilter: "")

        let payload = WatchTextFilter.payload(
            from: "  Merhaba dunya  ",
            previousText: nil,
            configuration: configuration
        )

        XCTAssertEqual(payload, "Merhaba dunya")
    }

    func testNewLinesOnlyReturnsOnlyFreshLines() {
        let configuration = WatchConfiguration(copyBehavior: .newLinesOnly, regexFilter: "")

        let payload = WatchTextFilter.payload(
            from: "Satir 1\nSatir 2\nSatir 3",
            previousText: "Satir 1\nSatir 2",
            configuration: configuration
        )

        XCTAssertEqual(payload, "Satir 3")
    }

    func testRegexFilterExtractsMatchingLinesOnly() {
        let configuration = WatchConfiguration(copyBehavior: .wholeResult, regexFilter: "ID-\\d+")

        let payload = WatchTextFilter.payload(
            from: "Durum: tamam\nID-42\nKalan: 3",
            previousText: nil,
            configuration: configuration
        )

        XCTAssertEqual(payload, "ID-42")
    }
}
