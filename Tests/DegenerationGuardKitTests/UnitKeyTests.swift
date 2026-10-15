@testable import DegenerationGuardKit
import XCTest

final class UnitKeyTests: XCTestCase {
    private func key(_ text: String, policy: DegenerationPolicy = .standard) -> String? {
        UnitKey.make(text, policy: policy)
    }

    func testCaseSpacingAndMarkersAreNotPartOfTheKey() {
        let expected = "check the config file."
        for text in [
            "Check  the config\tfile.", "  - Check the config file.", "* Check the config file.",
            "12) Check the config file.", "3. Check the config file.", "## Check the config file.",
            "> Check the config file. "
        ] {
            XCTAssertEqual(key(text), expected, text)
        }
    }

    func testTextThatOnlyLooksLikeAMarkerIsKept() {
        XCTAssertEqual(key("2026-10-15 was a Thursday"), "2026-10-15 was a thursday")
        XCTAssertEqual(key("1234. Four digits are a year"), "1234. four digits are a year")
        XCTAssertEqual(key("-dash without a space here"), "-dash without a space here")
        XCTAssertEqual(key("7.5 percent of the requests"), "7.5 percent of the requests")
    }

    func testMarkerAtTheEndLeavesNothingToCount() {
        XCTAssertNil(key("##"))
        XCTAssertNil(key("12"))
        XCTAssertNil(key("   "))
        XCTAssertEqual(UnitKey.markerEnd(Array("12".unicodeScalars)), 0)
        XCTAssertEqual(UnitKey.markerEnd(Array("##".unicodeScalars)), 0)
    }

    func testDigitRunsBecomeOneMarkWhenMasked() {
        XCTAssertEqual(key("Check 17 x 345 = 5865 now", policy: .reasoning), "check # x # = # now")
        XCTAssertEqual(key("Check 17 x 345 = 5865 now"), "check 17 x 345 = 5865 now")
    }

    func testUnitsWithoutLettersOrDigitsHaveNoKey() {
        XCTAssertNil(key("|--------|--------|"))
        XCTAssertNil(key("```"))
        XCTAssertEqual(key("|  2026  |  2027  |"), "| 2026 | 2027 |")
    }

    func testMinimumLengthIsCountedAfterNormalization() {
        let policy = DegenerationPolicy(minimumUnitScalars: 9)
        XCTAssertNil(key("1. A   B  C  D", policy: policy))  // "a b c d" is 7
        XCTAssertEqual(key("1. A   B  C  D  E", policy: policy), "a b c d e")
    }
}
