@testable import DegenerationGuardKit
import XCTest

final class VerbatimTests: XCTestCase {
    private func verbatim(_ text: String, policy: DegenerationPolicy = .standard) -> DegenerationFinding? {
        var monitor = DegenerationMonitor(detectors: [VerbatimLoopDetector(policy: policy)])
        monitor.ingest(text)
        return monitor.finish().finding
    }

    func testSentenceLoopIsCaughtAtTheFourthCopyOnceLongEnough() throws {
        let sentence = "The cache key must include the locale. "
        XCTAssertNil(verbatim("Intro. " + String(repeating: sentence, count: 3)))
        let finding = try XCTUnwrap(verbatim("Intro. " + String(repeating: sentence, count: 4)))
        XCTAssertEqual(finding.kind, .verbatim(period: 39, copies: 4))
        XCTAssertEqual(finding.sample, sentence)
        // The ". " of "Intro. " starts the periodic region, so four copies are complete 2 scalars early.
        XCTAssertEqual(finding.loopStart, 5)
        XCTAssertEqual(finding.detectedAt, 5 + 4 * 39)
    }

    func testShortBlockNeedsTheLongerRun() throws {
        XCTAssertNil(verbatim(String(repeating: "ab", count: 99) + "a"))
        let finding = try XCTUnwrap(verbatim(String(repeating: "ab", count: 100)))
        XCTAssertEqual(finding.kind, .verbatim(period: 2, copies: 100))
        XCTAssertEqual(finding.detectedAt, 200)
        XCTAssertEqual(finding.loopStart, 0)
    }

    /// "abababab" is a run of "ab": it is not excused by the 120-scalar threshold of 8-scalar
    /// blocks while "ab" itself is held to 200.
    func testRepetitiveBlockIsJudgedAtItsSmallestPeriod() {
        XCTAssertNil(verbatim(String(repeating: "abababab", count: 15)))
    }

    func testBlocksLongerThanTheMaximumPeriodAreNotFound() {
        let block = "This sentence is forty-four scalars long ok. "
        let policy = DegenerationPolicy(maximumPeriod: 16)
        XCTAssertNil(verbatim(String(repeating: block, count: 8), policy: policy))
        XCTAssertNotNil(verbatim(String(repeating: block, count: 8)))
    }

    func testCutPrefersASentenceBoundaryThenAWordBoundary() throws {
        let text = "Done first. " + String(repeating: "Then retry the step. ", count: 8)
        let sentence = try XCTUnwrap(verbatim(text))
        XCTAssertEqual(DegenerationGuard.salvage(text, keeping: sentence).text, "Done first. Then retry the step.")

        let words = "go" + String(repeating: " on and", count: 40)
        let word = try XCTUnwrap(verbatim(words))
        XCTAssertEqual(DegenerationGuard.salvage(words, keeping: word).text, "go on and")
    }

    func testCutWithoutWhitespaceKeepsOneBlock() throws {
        let text = "id:" + String(repeating: "xyz", count: 80)
        let finding = try XCTUnwrap(verbatim(text))
        XCTAssertEqual(finding.kind, .verbatim(period: 3, copies: 66))
        XCTAssertEqual(finding.detectedAt, 3 + 200)
        XCTAssertEqual(DegenerationGuard.salvage(text, keeping: finding).text, "id:xyz")
    }

    func testFloodFromTheFirstScalar() throws {
        let finding = try XCTUnwrap(verbatim(String(repeating: "\n", count: 250)))
        XCTAssertEqual(finding.loopStart, 0)
        XCTAssertEqual(finding.keepThrough, 1)
        XCTAssertEqual(finding.kind.description, "verbatim: a 1-scalar block written 200 times in a row")
    }

    func testEmojiBlockIsCutOnWholeScalars() throws {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} "
        let text = "Family:" + String(repeating: family, count: 40)
        let finding = try XCTUnwrap(verbatim(text))
        XCTAssertEqual(finding.kind, .verbatim(period: 6, copies: 33))
        XCTAssertEqual(DegenerationGuard.salvage(text, keeping: finding).text, "Family:" + family.dropLast())
    }
}
