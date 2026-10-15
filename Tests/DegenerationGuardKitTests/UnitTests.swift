@testable import DegenerationGuardKit
import XCTest

final class UnitTests: XCTestCase {
    private func units(_ text: String, policy: DegenerationPolicy = .standard) -> DegenerationFinding? {
        var monitor = DegenerationMonitor(detectors: [UnitCycleDetector(policy: policy)])
        monitor.ingest(text)
        return monitor.finish().finding
    }

    func testFourCopiesOfASentenceAreACycleThreeAreNot() throws {
        let line = "Retrying the request now.\n"
        XCTAssertNil(units(String(repeating: line, count: 3)))
        let finding = try XCTUnwrap(units("Start.\n" + String(repeating: line, count: 4)))
        XCTAssertEqual(finding.kind, .unitCycle(units: 1, copies: 4))
        XCTAssertEqual(finding.loopStart, 7)
        XCTAssertEqual(finding.keepThrough, 7 + 26)
        XCTAssertEqual(finding.kind.description, "unit cycle: the same sentence written 4 times in a row")
    }

    func testSongWithAQuadrupleChorusIsACycle() throws {
        let chorus = "Rise again, rise again tonight,\nrise again, rise again tonight,\nwe will hold the morning light.\n"
        XCTAssertNil(units("Verse.\n" + String(repeating: chorus, count: 3)))
        let finding = try XCTUnwrap(units("Verse.\n" + String(repeating: chorus, count: 4)))
        XCTAssertEqual(finding.kind, .unitCycle(units: 3, copies: 4))
        XCTAssertEqual(finding.kind.description, "unit cycle: the same run of 3 sentences written 4 times in a row")
    }

    func testOnlyWhitespaceAfterATerminatorEndsAUnit() {
        let text = String(repeating: "Pi is 3.14 and e is 2.71, roughly.", count: 5)
        XCTAssertNil(units(text))
        XCTAssertNotNil(units(String(repeating: "Pi is 3.14 and e is 2.71, roughly. ", count: 4)))
    }

    func testWideTerminatorsEndAUnitWithoutSpace() throws {
        let sentence = "\u{8BF7}\u{518D}\u{786E}\u{8BA4}\u{4E00}\u{6B21}\u{8FD9}\u{4E2A}\u{6570}\u{5B57}\u{518D}\u{770B}\u{FF01}"
        let finding = try XCTUnwrap(units(String(repeating: sentence, count: 4)))
        XCTAssertEqual(finding.keepThrough, 13)
    }

    func testUnitsWithoutWordsOrTooShortAreNotCounted() {
        XCTAssertNil(units(String(repeating: "|---|---|---|---|\n", count: 10)))
        XCTAssertNil(units(String(repeating: "Yes, done.\n", count: 10)))
        XCTAssertNil(units(String(repeating: "\n\n   \n", count: 10)))
    }

    func testUnfinishedLastUnitIsJudgedAtFinish() throws {
        let text = String(repeating: "Checking the cache again\n", count: 3) + "Checking the cache again"
        var monitor = DegenerationMonitor(detectors: [UnitCycleDetector()])
        XCTAssertNil(monitor.ingest(text).finding)
        let finding = try XCTUnwrap(monitor.finish().finding)
        XCTAssertEqual(finding.detectedAt, text.unicodeScalars.count)
    }

    func testLongHistoryIsTrimmedWithoutLosingCycles() {
        let distinct = (1...60).map { "Sentence number \($0) is different.\n" }.joined()
        XCTAssertNil(units(distinct))
        XCTAssertNotNil(units(distinct + String(repeating: "Now the loop begins here.\n", count: 4)))
    }

    func testDigitMaskingIsAPolicyChoice() {
        let text = (1...6).map { "Row \($0) total is \($0 * 11)." }.joined(separator: " ")
        XCTAssertNil(units(text))
        XCTAssertNotNil(units(text, policy: .reasoning))
    }
}
