@testable import DegenerationGuardKit
import XCTest

final class MonitorTests: XCTestCase {
    func testFindingIsFinalAndLaterTextIsCountedNotExamined() throws {
        var monitor = DegenerationMonitor()
        let loop = String(repeating: "Wait, let me reconsider the units. ", count: 6)
        let verdict = monitor.ingest(loop)
        let finding = try XCTUnwrap(verdict.finding)
        XCTAssertEqual(monitor.scalarsAfterDetection, loop.unicodeScalars.count - finding.detectedAt)
        monitor.ingest("A completely different ending.")
        XCTAssertEqual(monitor.finding, finding)
        XCTAssertEqual(monitor.scanned, loop.unicodeScalars.count + 30)
        XCTAssertEqual(monitor.finish(), .degenerate(finding))
    }

    func testCleanStreamReportsWhatItScanned() {
        var monitor = DegenerationMonitor()
        XCTAssertEqual(monitor.ingest("Hello there."), .clean(scanned: 12))
        XCTAssertEqual(monitor.scalarsAfterDetection, 0)
        XCTAssertNil(monitor.verdict.finding)
        XCTAssertEqual(monitor.history.text(0..<5), "Hello")
    }

    func testFinishIsIdempotentAndLaterTextIsNotExamined() {
        var monitor = DegenerationMonitor(detectors: [MarkerDetector()])
        XCTAssertEqual(monitor.finish(), .clean(scanned: 0))
        monitor.ingest("~")
        XCTAssertEqual(monitor.finish(), .clean(scanned: 1))
    }

    func testCustomDetectorsAreAskedInOrder() throws {
        var monitor = DegenerationMonitor(detectors: [MarkerDetector(trigger: "!"), MarkerDetector(trigger: "~")])
        let finding = try XCTUnwrap(monitor.ingest("abc~def").finding)
        XCTAssertEqual(finding.kind, .custom("marker"))
        XCTAssertEqual(finding.detectedAt, 4)
        XCTAssertEqual(finding.kind.description, "custom: marker")
    }

    func testFinishAsksEveryDetectorUntilOneReports() throws {
        var monitor = DegenerationMonitor(detectors: [MarkerDetector(), MarkerDetector(atFinish: true)])
        monitor.ingest("plain text")
        let finding = try XCTUnwrap(monitor.finish().finding)
        XCTAssertEqual(finding.detectedAt, 10)
    }

    func testHistoryTextClampsToWhatWasReceived() {
        var monitor = DegenerationMonitor()
        monitor.ingest("abc")
        XCTAssertEqual(monitor.history.text(-5..<99), "abc")
        XCTAssertEqual(monitor.history.text(5..<9), "")
        XCTAssertEqual(monitor.history[1], "b")
    }

    func testSalvageClampsAnOffsetBeyondTheText() {
        let finding = DegenerationFinding(kind: .custom("x"), detectedAt: 3, loopStart: 0, keepThrough: 99, sample: "")
        XCTAssertEqual(
            DegenerationGuard.salvage("abc \n", keeping: finding),
            Salvage(text: "abc", keptScalars: 3, removedScalars: 2)
        )
        let negative = DegenerationFinding(kind: .custom("x"), detectedAt: 3, loopStart: 0, keepThrough: -4, sample: "")
        XCTAssertEqual(DegenerationGuard.salvage("abc", keeping: negative).text, "")
    }

    func testPolicyClampsNonsense() {
        let policy = DegenerationPolicy(
            maximumPeriod: 0,
            minimumCopies: 1,
            minimumLoopScalars: -3,
            shortPeriodLimit: 0,
            minimumRunScalars: 0,
            maximumUnitPeriod: 0,
            minimumUnitScalars: 0
        )
        XCTAssertEqual(policy.maximumPeriod, 1)
        XCTAssertEqual(policy.minimumCopies, 2)
        XCTAssertEqual(policy.minimumLoopScalars, 1)
        XCTAssertEqual(policy.shortPeriodLimit, 1)
        XCTAssertEqual(policy.minimumRunScalars, 1)
        XCTAssertEqual(policy.maximumUnitPeriod, 1)
        XCTAssertEqual(policy.minimumUnitScalars, 1)
        XCTAssertFalse(policy.maskDigits)
        XCTAssertTrue(DegenerationPolicy.reasoning.maskDigits)
        XCTAssertEqual(DegenerationPolicy.standard.requiredCoverage(forPeriod: 7), 200)
        XCTAssertEqual(DegenerationPolicy.standard.requiredCoverage(forPeriod: 8), 120)
    }
}
